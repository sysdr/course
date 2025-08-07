package com.logplatform.sdk;

import com.fasterxml.jackson.databind.DeserializationFeature;
import com.fasterxml.jackson.databind.ObjectMapper;
import com.fasterxml.jackson.databind.SerializationFeature;
import com.fasterxml.jackson.datatype.jsr310.JavaTimeModule;
import okhttp3.*;
import org.java_websocket.client.WebSocketClient;
import org.java_websocket.handshake.ServerHandshake;

import java.io.IOException;
import java.net.URI;
import java.time.Duration;
import java.util.List;
import java.util.Map;
import java.util.concurrent.CompletableFuture;
import java.util.concurrent.TimeUnit;
import java.util.function.Consumer;

public class LogPlatformClient implements AutoCloseable {
    private final Config config;
    private final OkHttpClient httpClient;
    private final ObjectMapper objectMapper;
    private WebSocketClient webSocketClient;
    
    public LogPlatformClient(Config config) {
        this.config = config;
        this.httpClient = new OkHttpClient.Builder()
            .connectTimeout(Duration.ofSeconds(config.getTimeout()))
            .readTimeout(Duration.ofSeconds(config.getTimeout()))
            .build();
        
        this.objectMapper = new ObjectMapper();
        this.objectMapper.registerModule(new JavaTimeModule());
        this.objectMapper.disable(SerializationFeature.WRITE_DATES_AS_TIMESTAMPS);
        this.objectMapper.configure(DeserializationFeature.FAIL_ON_UNKNOWN_PROPERTIES, false);
        this.objectMapper.configure(DeserializationFeature.ADJUST_DATES_TO_CONTEXT_TIME_ZONE, false);
    }
    
    public LogPlatformClient() {
        this(new Config());
    }
    
    public SubmitResponse submitLog(LogEntry logEntry) throws LogPlatformException {
        try {
            String json = objectMapper.writeValueAsString(logEntry);
            RequestBody body = RequestBody.create(json, MediaType.get("application/json"));
            
            Request request = new Request.Builder()
                .url(config.getBaseUrl() + "/api/v1/logs")
                .addHeader("Authorization", "Bearer " + config.getApiKey())
                .addHeader("User-Agent", "logplatform-java-sdk/1.0.0")
                .post(body)
                .build();
            
            try (Response response = httpClient.newCall(request).execute()) {
                if (!response.isSuccessful()) {
                    throw new LogPlatformException("Failed to submit log: " + response.code());
                }
                
                String responseBody = response.body() != null ? response.body().string() : "{}";
                return objectMapper.readValue(responseBody, SubmitResponse.class);
            }
        } catch (IOException e) {
            throw new LogPlatformException("Network error: " + e.getMessage(), e);
        }
    }
    
    public CompletableFuture<SubmitResponse> submitLogAsync(LogEntry logEntry) {
        return CompletableFuture.supplyAsync(() -> {
            try {
                return submitLog(logEntry);
            } catch (LogPlatformException e) {
                throw new RuntimeException(e);
            }
        });
    }
    
    public BatchSubmitResponse submitLogsBatch(List<LogEntry> logEntries) throws LogPlatformException {
        try {
            Map<String, Object> payload = Map.of("logs", logEntries);
            String json = objectMapper.writeValueAsString(payload);
            RequestBody body = RequestBody.create(json, MediaType.get("application/json"));
            
            Request request = new Request.Builder()
                .url(config.getBaseUrl() + "/api/v1/logs/batch")
                .addHeader("Authorization", "Bearer " + config.getApiKey())
                .addHeader("User-Agent", "logplatform-java-sdk/1.0.0")
                .post(body)
                .build();
            
            try (Response response = httpClient.newCall(request).execute()) {
                if (!response.isSuccessful()) {
                    throw new LogPlatformException("Failed to submit batch: " + response.code());
                }
                
                String responseBody = response.body() != null ? response.body().string() : "{}";
                return objectMapper.readValue(responseBody, BatchSubmitResponse.class);
            }
        } catch (IOException e) {
            throw new LogPlatformException("Network error: " + e.getMessage(), e);
        }
    }
    
    public QueryResult queryLogs(String query, int limit) throws LogPlatformException {
        try {
            HttpUrl url = HttpUrl.parse(config.getBaseUrl() + "/api/v1/logs/query")
                .newBuilder()
                .addQueryParameter("q", query)
                .addQueryParameter("limit", String.valueOf(limit))
                .build();
            
            Request request = new Request.Builder()
                .url(url)
                .addHeader("Authorization", "Bearer " + config.getApiKey())
                .addHeader("User-Agent", "logplatform-java-sdk/1.0.0")
                .get()
                .build();
            
            try (Response response = httpClient.newCall(request).execute()) {
                if (!response.isSuccessful()) {
                    throw new LogPlatformException("Failed to query logs: " + response.code());
                }
                
                String responseBody = response.body() != null ? response.body().string() : "{}";
                return objectMapper.readValue(responseBody, QueryResult.class);
            }
        } catch (IOException e) {
            throw new LogPlatformException("Network error: " + e.getMessage(), e);
        }
    }
    
    public void streamLogs(StreamConfig streamConfig, Consumer<LogEntry> onLogReceived, 
                          Consumer<Exception> onError) throws LogPlatformException {
        try {
            URI uri = URI.create(config.getWebsocketUrl() + "/api/v1/logs/stream");
            
            webSocketClient = new WebSocketClient(uri) {
                @Override
                public void onOpen(ServerHandshake handshake) {
                    try {
                        String configJson = objectMapper.writeValueAsString(streamConfig);
                        send(configJson);
                    } catch (Exception e) {
                        onError.accept(e);
                    }
                }
                
                @Override
                public void onMessage(String message) {
                    try {
                        Map<String, Object> data = objectMapper.readValue(message, Map.class);
                        if ("log".equals(data.get("type"))) {
                            LogEntry logEntry = objectMapper.convertValue(data.get("payload"), LogEntry.class);
                            onLogReceived.accept(logEntry);
                        } else if ("error".equals(data.get("type"))) {
                            onError.accept(new LogPlatformException((String) data.get("message")));
                        }
                    } catch (Exception e) {
                        onError.accept(e);
                    }
                }
                
                @Override
                public void onClose(int code, String reason, boolean remote) {
                    // Connection closed
                }
                
                @Override
                public void onError(Exception ex) {
                    onError.accept(ex);
                }
            };
            
            webSocketClient.addHeader("Authorization", "Bearer " + config.getApiKey());
            webSocketClient.connect();
            
        } catch (Exception e) {
            throw new LogPlatformException("Failed to connect WebSocket: " + e.getMessage(), e);
        }
    }
    
    public HealthResponse healthCheck() throws LogPlatformException {
        try {
            Request request = new Request.Builder()
                .url(config.getBaseUrl() + "/api/v1/health")
                .addHeader("Authorization", "Bearer " + config.getApiKey())
                .get()
                .build();
            
            try (Response response = httpClient.newCall(request).execute()) {
                if (!response.isSuccessful()) {
                    throw new LogPlatformException("Health check failed: " + response.code());
                }
                
                String responseBody = response.body() != null ? response.body().string() : "{}";
                return objectMapper.readValue(responseBody, HealthResponse.class);
            }
        } catch (IOException e) {
            throw new LogPlatformException("Network error: " + e.getMessage(), e);
        }
    }
    
    @Override
    public void close() {
        if (webSocketClient != null) {
            webSocketClient.close();
        }
        httpClient.dispatcher().executorService().shutdown();
        httpClient.connectionPool().evictAll();
    }
}
