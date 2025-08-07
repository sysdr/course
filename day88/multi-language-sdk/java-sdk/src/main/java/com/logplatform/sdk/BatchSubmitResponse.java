package com.logplatform.sdk;

import com.fasterxml.jackson.annotation.JsonProperty;
import java.util.List;

public class BatchSubmitResponse {
    @JsonProperty("success")
    private boolean success;
    
    @JsonProperty("processedCount")
    private int processedCount;
    
    @JsonProperty("failedCount")
    private int failedCount;
    
    @JsonProperty("logIds")
    private List<String> logIds;
    
    @JsonProperty("message")
    private String message;

    public BatchSubmitResponse() {}

    public BatchSubmitResponse(boolean success, int processedCount, int failedCount, List<String> logIds, String message) {
        this.success = success;
        this.processedCount = processedCount;
        this.failedCount = failedCount;
        this.logIds = logIds;
        this.message = message;
    }

    // Getters
    public boolean isSuccess() { return success; }
    public int getProcessedCount() { return processedCount; }
    public int getFailedCount() { return failedCount; }
    public List<String> getLogIds() { return logIds; }
    public String getMessage() { return message; }

    // Setters
    public void setSuccess(boolean success) { this.success = success; }
    public void setProcessedCount(int processedCount) { this.processedCount = processedCount; }
    public void setFailedCount(int failedCount) { this.failedCount = failedCount; }
    public void setLogIds(List<String> logIds) { this.logIds = logIds; }
    public void setMessage(String message) { this.message = message; }
}
