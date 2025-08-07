import { Config } from './config';
import { LogEntry, QueryResult, StreamConfig, SubmitResponse, HealthResponse } from './types';
import { LogPlatformError, ConnectionError } from './exceptions';
import WebSocket from 'ws';

export class LogPlatformClient {
    private config: Config;
    private ws?: WebSocket;

    constructor(config?: Partial<Config>) {
        this.config = { ...new Config(), ...config };
    }

    async submitLog(logEntry: LogEntry): Promise<SubmitResponse> {
        try {
            const response = await this.makeRequest('/api/v1/logs', {
                method: 'POST',
                body: JSON.stringify(logEntry)
            });
            
            if (!response.ok) {
                throw new ConnectionError(`Failed to submit log: ${response.status}`);
            }
            
            return await response.json() as SubmitResponse;
        } catch (error) {
            if (error instanceof LogPlatformError) throw error;
            throw new ConnectionError(`Network error: ${error}`);
        }
    }

    async submitLogsBatch(logEntries: LogEntry[]): Promise<SubmitResponse> {
        try {
            const response = await this.makeRequest('/api/v1/logs/batch', {
                method: 'POST',
                body: JSON.stringify({ logs: logEntries })
            });
            
            if (!response.ok) {
                throw new ConnectionError(`Failed to submit batch: ${response.status}`);
            }
            
            return await response.json() as SubmitResponse;
        } catch (error) {
            if (error instanceof LogPlatformError) throw error;
            throw new ConnectionError(`Network error: ${error}`);
        }
    }

    async queryLogs(query: string, limit: number = 100): Promise<QueryResult> {
        try {
            const url = new URL('/api/v1/logs/query', this.config.baseUrl);
            url.searchParams.append('q', query);
            url.searchParams.append('limit', limit.toString());

            const response = await this.makeRequest(url.pathname + url.search);
            
            if (!response.ok) {
                throw new ConnectionError(`Failed to query logs: ${response.status}`);
            }
            
            const data = await response.json();
            return {
                logs: data.logs.map((log: any) => ({
                    ...log,
                    timestamp: new Date(log.timestamp)
                })),
                totalCount: data.total_count,
                queryTimeMs: data.query_time_ms
            };
        } catch (error) {
            if (error instanceof LogPlatformError) throw error;
            throw new ConnectionError(`Network error: ${error}`);
        }
    }

    streamLogs(
        streamConfig: StreamConfig,
        onLogReceived: (log: LogEntry) => void,
        onError?: (error: Error) => void
    ): () => void {
        const wsUrl = this.config.websocketUrl.replace('http', 'ws') + '/api/v1/logs/stream';
        
        this.ws = new WebSocket(wsUrl, {
            headers: {
                'Authorization': `Bearer ${this.config.apiKey}`
            }
        });

        this.ws.on('open', () => {
            if (this.ws) {
                this.ws.send(JSON.stringify(streamConfig));
            }
        });

        this.ws.on('message', (data: WebSocket.Data) => {
            try {
                const message = JSON.parse(data.toString());
                
                if (message.type === 'log') {
                    const logEntry: LogEntry = {
                        ...message.payload,
                        timestamp: new Date(message.payload.timestamp)
                    };
                    onLogReceived(logEntry);
                } else if (message.type === 'error') {
                    onError?.(new LogPlatformError(message.message));
                }
            } catch (error) {
                onError?.(new Error(`Failed to parse message: ${error}`));
            }
        });

        this.ws.on('error', (error) => {
            onError?.(new ConnectionError(`WebSocket error: ${error.message}`));
        });

        this.ws.on('close', () => {
            // Connection closed
        });

        // Return cleanup function
        return () => {
            if (this.ws) {
                this.ws.close();
                this.ws = undefined;
            }
        };
    }

    async healthCheck(): Promise<HealthResponse> {
        try {
            const response = await this.makeRequest('/api/v1/health');
            
            if (!response.ok) {
                throw new ConnectionError(`Health check failed: ${response.status}`);
            }
            
            return await response.json() as HealthResponse;
        } catch (error) {
            if (error instanceof LogPlatformError) throw error;
            throw new ConnectionError(`Network error: ${error}`);
        }
    }

    private async makeRequest(path: string, options: RequestInit = {}): Promise<Response> {
        const url = path.startsWith('http') ? path : `${this.config.baseUrl}${path}`;
        
        const defaultOptions: RequestInit = {
            headers: {
                'Authorization': `Bearer ${this.config.apiKey}`,
                'Content-Type': 'application/json',
                'User-Agent': 'logplatform-js-sdk/1.0.0'
            },
            ...options
        };

        // Use dynamic import for node-fetch to support both Node.js and browser
        if (typeof fetch === 'undefined') {
            const nodeFetch = await import('node-fetch');
            return nodeFetch.default(url, defaultOptions) as Promise<Response>;
        }
        
        return fetch(url, defaultOptions);
    }

    close(): void {
        if (this.ws) {
            this.ws.close();
            this.ws = undefined;
        }
    }
}
