const { LogPlatformClient } = require('../dist/index.js');

// Mock fetch for Node.js environment
global.fetch = jest.fn();

describe('LogPlatformClient', () => {
    let client;
    
    beforeEach(() => {
        client = new LogPlatformClient({
            apiKey: 'test-key',
            baseUrl: 'http://test.example.com',
            websocketUrl: 'ws://test.example.com'
        });
        
        fetch.mockClear();
    });
    
    afterEach(() => {
        client.close();
    });
    
    test('submitLog success', async () => {
        const mockResponse = {
            ok: true,
            json: jest.fn().mockResolvedValue({
                success: true,
                logId: 'test-123'
            })
        };
        
        fetch.mockResolvedValue(mockResponse);
        
        const logEntry = {
            level: 'INFO',
            message: 'Test message',
            service: 'test-service',
            timestamp: new Date()
        };
        
        const result = await client.submitLog(logEntry);
        
        expect(result.success).toBe(true);
        expect(result.logId).toBe('test-123');
        expect(fetch).toHaveBeenCalledWith(
            'http://test.example.com/api/v1/logs',
            expect.objectContaining({
                method: 'POST',
                headers: expect.objectContaining({
                    'Authorization': 'Bearer test-key'
                })
            })
        );
    });
    
    test('submitLog failure', async () => {
        const mockResponse = {
            ok: false,
            status: 500
        };
        
        fetch.mockResolvedValue(mockResponse);
        
        const logEntry = {
            level: 'INFO',
            message: 'Test message',
            service: 'test-service',
            timestamp: new Date()
        };
        
        await expect(client.submitLog(logEntry))
            .rejects
            .toThrow('Failed to submit log: 500');
    });
    
    test('queryLogs success', async () => {
        const mockResponse = {
            ok: true,
            json: jest.fn().mockResolvedValue({
                logs: [
                    {
                        timestamp: '2024-01-01T00:00:00.000Z',
                        level: 'INFO',
                        message: 'Test log',
                        service: 'test-service',
                        metadata: {}
                    }
                ],
                total_count: 1,
                query_time_ms: 50
            })
        };
        
        fetch.mockResolvedValue(mockResponse);
        
        const result = await client.queryLogs('test query', 10);
        
        expect(result.logs).toHaveLength(1);
        expect(result.totalCount).toBe(1);
        expect(result.queryTimeMs).toBe(50);
    });
    
    test('healthCheck success', async () => {
        const mockResponse = {
            ok: true,
            json: jest.fn().mockResolvedValue({
                status: 'healthy',
                timestamp: '2024-01-01T00:00:00.000Z',
                version: '1.0.0'
            })
        };
        
        fetch.mockResolvedValue(mockResponse);
        
        const result = await client.healthCheck();
        
        expect(result.status).toBe('healthy');
        expect(result.version).toBe('1.0.0');
    });
});
