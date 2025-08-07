export interface LogEntry {
    timestamp: Date;
    level: string;
    message: string;
    service: string;
    metadata?: Record<string, any>;
}

export interface QueryResult {
    logs: LogEntry[];
    totalCount: number;
    queryTimeMs: number;
}

export interface StreamConfig {
    filters?: Record<string, any>;
    bufferSize?: number;
    realTime?: boolean;
}

export interface SubmitResponse {
    success: boolean;
    logId?: string;
    message?: string;
}

export interface HealthResponse {
    status: string;
    timestamp: string;
    version: string;
    uptime: number;
}
