#!/usr/bin/env node

const { LogPlatformClient, Config } = require('../dist/index.js');

async function main() {
    console.log('🟨 JavaScript SDK Demo');
    console.log('='.repeat(50));
    
    // Configure the client
    const config = {
        apiKey: 'demo-api-key-12345',
        baseUrl: 'http://localhost:8000',
        websocketUrl: 'ws://localhost:8000'
    };
    
    const client = new LogPlatformClient(config);
    
    try {
        // Submit a single log
        const logEntry = {
            level: 'INFO',
            message: 'JavaScript SDK test message',
            service: 'demo-service',
            timestamp: new Date(),
            metadata: { source: 'js-example', user_id: '789' }
        };
        
        console.log('📝 Submitting single log...');
        const result = await client.submitLog(logEntry);
        console.log('✅ Result:', result);
        
        // Submit batch logs
        const batchLogs = Array.from({ length: 5 }, (_, i) => ({
            level: i === 4 ? 'ERROR' : 'INFO',
            message: `Batch message ${i + 1}`,
            service: 'batch-service',
            timestamp: new Date(),
            metadata: {}
        }));
        
        console.log('\n📦 Submitting batch logs...');
        const batchResult = await client.submitLogsBatch(batchLogs);
        console.log('✅ Batch result:', batchResult);
        
        // Query logs
        console.log('\n🔍 Querying logs...');
        const queryResult = await client.queryLogs('INFO', 10);
        console.log(`✅ Found ${queryResult.logs.length} logs in ${queryResult.queryTimeMs}ms`);
        
        // Stream logs
        console.log('\n🌊 Streaming logs for 10 seconds...');
        const streamConfig = { realTime: true, bufferSize: 100 };
        
        let streamCount = 0;
        const cleanup = client.streamLogs(
            streamConfig,
            (log) => {
                console.log(`📨 Streamed log: ${log.message}`);
                streamCount++;
            },
            (error) => console.error('❌ Stream error:', error.message)
        );
        
        // Wait for streaming demo
        await new Promise(resolve => setTimeout(resolve, 5000));
        cleanup();
        console.log(`📊 Received ${streamCount} streamed messages`);
        
        // Health check
        console.log('\n❤️ Health check...');
        const health = await client.healthCheck();
        console.log('✅ Platform status:', health.status);
        
    } catch (error) {
        console.error('❌ Demo failed:', error.message);
    } finally {
        client.close();
    }
}

if (require.main === module) {
    main().catch(console.error);
}
