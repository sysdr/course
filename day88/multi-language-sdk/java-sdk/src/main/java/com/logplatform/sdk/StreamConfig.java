package com.logplatform.sdk;

import com.fasterxml.jackson.annotation.JsonProperty;
import java.util.Map;

public class StreamConfig {
    @JsonProperty("filters")
    private Map<String, Object> filters;
    
    @JsonProperty("bufferSize")
    private int bufferSize;
    
    @JsonProperty("realTime")
    private boolean realTime;

    public StreamConfig() {
        this.filters = Map.of();
        this.bufferSize = 100;
        this.realTime = true;
    }

    public StreamConfig(Map<String, Object> filters, int bufferSize, boolean realTime) {
        this.filters = filters != null ? filters : Map.of();
        this.bufferSize = bufferSize;
        this.realTime = realTime;
    }

    // Getters
    public Map<String, Object> getFilters() { return filters; }
    public int getBufferSize() { return bufferSize; }
    public boolean isRealTime() { return realTime; }

    // Setters
    public void setFilters(Map<String, Object> filters) { this.filters = filters; }
    public void setBufferSize(int bufferSize) { this.bufferSize = bufferSize; }
    public void setRealTime(boolean realTime) { this.realTime = realTime; }
}
