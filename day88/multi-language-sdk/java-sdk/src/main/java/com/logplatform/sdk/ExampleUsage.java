package com.logplatform.sdk;

import com.fasterxml.jackson.databind.ObjectMapper;
import com.fasterxml.jackson.datatype.jsr310.JavaTimeModule;
import java.time.LocalDateTime;
import java.util.Arrays;
import java.util.HashMap;
import java.util.List;
import java.util.Map;
import java.util.concurrent.CompletableFuture;
import java.util.concurrent.TimeUnit;

public class ExampleUsage {
    public static void main(String[] args) {
        System.out.println("☕ Java SDK Demo");
        System.out.println("=".repeat(50));
        
        // Configure the client
        Config config = new Config();
        config.setApiKey("demo-api-key-12345");
        config.setBaseUrl("http://localhost:8000");
        config.setWebsocketUrl("ws://localhost:8000");
        
        try (LogPlatformClient client = new LogPlatformClient(config)) {
            
            // Submit a single log
            Map<String, Object> metadata = new HashMap<>();
            metadata.put("source", "java-example");
            metadata.put("user_id", "456");
            
            LogEntry logEntry = new LogEntry(
                "INFO",
                "Java SDK test message",
                "demo-service",
                metadata
            );
            
            System.out.println("📝 Submitting single log...");
            // Debug: Print the JSON being sent
            ObjectMapper mapper = new ObjectMapper();
            mapper.registerModule(new JavaTimeModule());
            try {
                String json = mapper.writeValueAsString(logEntry);
                System.out.println("🔍 Debug JSON: " + json);
            } catch (Exception e) {
                System.err.println("❌ JSON serialization error: " + e.getMessage());
            }
            SubmitResponse result = client.submitLog(logEntry);
            System.out.println("✅ Result: " + result);
            
            // Submit batch logs with async
            List<LogEntry> batchLogs = Arrays.asList(
                new LogEntry("INFO", "Batch message 1", "batch-service", new HashMap<>()),
                new LogEntry("INFO", "Batch message 2", "batch-service", new HashMap<>()),
                new LogEntry("ERROR", "Batch error message", "batch-service", new HashMap<>())
            );
            
            System.out.println("\n📦 Submitting batch logs asynchronously...");
            CompletableFuture<BatchSubmitResponse> batchFuture = CompletableFuture.supplyAsync(() -> {
                try {
                    return client.submitLogsBatch(batchLogs);
                } catch (LogPlatformException e) {
                    throw new RuntimeException(e);
                }
            });
            
            BatchSubmitResponse batchResult = batchFuture.get(10, TimeUnit.SECONDS);
            System.out.println("✅ Batch result: " + batchResult);
            
            // Query logs
            System.out.println("\n🔍 Querying logs...");
            QueryResult queryResult = client.queryLogs("INFO", 10);
            System.out.println("✅ Found " + queryResult.getLogs().size() + " logs in " + 
                             queryResult.getQueryTimeMs() + "ms");
            
            // Stream logs
            System.out.println("\n🌊 Streaming logs for 10 seconds...");
            StreamConfig streamConfig = new StreamConfig();
            streamConfig.setRealTime(true);
            streamConfig.setBufferSize(100);
            
            final int[] streamCount = {0};
            client.streamLogs(
                streamConfig,
                (log) -> {
                    System.out.println("📨 Streamed log: " + log.getMessage());
                    streamCount[0]++;
                },
                (error) -> System.err.println("❌ Stream error: " + error.getMessage())
            );
            
            // Wait for a few streamed messages
            Thread.sleep(5000);
            System.out.println("📊 Received " + streamCount[0] + " streamed messages");
            
            // Health check
            System.out.println("\n❤️ Health check...");
            HealthResponse health = client.healthCheck();
            System.out.println("✅ Platform status: " + health.getStatus());
            
        } catch (Exception e) {
            System.err.println("❌ Demo failed: " + e.getMessage());
            e.printStackTrace();
        }
    }
}
