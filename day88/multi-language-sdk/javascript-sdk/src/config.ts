export class Config {
    apiKey: string;
    baseUrl: string;
    websocketUrl: string;
    timeout: number;
    maxRetries: number;
    retryDelay: number;

    constructor() {
        this.apiKey = process.env.LOGPLATFORM_API_KEY || '';
        this.baseUrl = process.env.LOGPLATFORM_BASE_URL || 'http://localhost:8000';
        this.websocketUrl = process.env.LOGPLATFORM_WS_URL || 'ws://localhost:8000';
        this.timeout = parseInt(process.env.LOGPLATFORM_TIMEOUT || '30000');
        this.maxRetries = parseInt(process.env.LOGPLATFORM_MAX_RETRIES || '3');
        this.retryDelay = parseFloat(process.env.LOGPLATFORM_RETRY_DELAY || '1.0');
    }
}
