package com.logplatform.sdk;

import java.time.Duration;

public class Config {
    private String apiKey;
    private String baseUrl;
    private String websocketUrl;
    private int timeout;
    private int maxRetries;
    private double retryDelay;

    public Config() {
        this.apiKey = System.getenv("LOGPLATFORM_API_KEY");
        this.baseUrl = System.getenv("LOGPLATFORM_BASE_URL");
        if (this.baseUrl == null || this.baseUrl.isEmpty()) {
            this.baseUrl = "http://localhost:8000";
        }
        this.websocketUrl = System.getenv("LOGPLATFORM_WS_URL");
        if (this.websocketUrl == null || this.websocketUrl.isEmpty()) {
            this.websocketUrl = "ws://localhost:8000";
        }
        this.timeout = 30;
        this.maxRetries = 3;
        this.retryDelay = 1.0;
    }

    public Config(String apiKey, String baseUrl, String websocketUrl, int timeout, int maxRetries, double retryDelay) {
        this.apiKey = apiKey;
        this.baseUrl = baseUrl;
        this.websocketUrl = websocketUrl;
        this.timeout = timeout;
        this.maxRetries = maxRetries;
        this.retryDelay = retryDelay;
    }

    // Getters
    public String getApiKey() { return apiKey; }
    public String getBaseUrl() { return baseUrl; }
    public String getWebsocketUrl() { return websocketUrl; }
    public int getTimeout() { return timeout; }
    public int getMaxRetries() { return maxRetries; }
    public double getRetryDelay() { return retryDelay; }

    // Setters
    public void setApiKey(String apiKey) { this.apiKey = apiKey; }
    public void setBaseUrl(String baseUrl) { this.baseUrl = baseUrl; }
    public void setWebsocketUrl(String websocketUrl) { this.websocketUrl = websocketUrl; }
    public void setTimeout(int timeout) { this.timeout = timeout; }
    public void setMaxRetries(int maxRetries) { this.maxRetries = maxRetries; }
    public void setRetryDelay(double retryDelay) { this.retryDelay = retryDelay; }
}
