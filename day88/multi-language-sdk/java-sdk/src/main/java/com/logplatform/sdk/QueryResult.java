package com.logplatform.sdk;

import com.fasterxml.jackson.annotation.JsonProperty;
import java.util.List;

public class QueryResult {
    @JsonProperty("logs")
    private List<LogEntry> logs;
    
    @JsonProperty("totalCount")
    private int totalCount;
    
    @JsonProperty("queryTimeMs")
    private int queryTimeMs;

    public QueryResult() {
        this.logs = List.of();
        this.totalCount = 0;
        this.queryTimeMs = 0;
    }

    public QueryResult(List<LogEntry> logs, int totalCount, int queryTimeMs) {
        this.logs = logs != null ? logs : List.of();
        this.totalCount = totalCount;
        this.queryTimeMs = queryTimeMs;
    }

    // Getters
    public List<LogEntry> getLogs() { return logs; }
    public int getTotalCount() { return totalCount; }
    public int getQueryTimeMs() { return queryTimeMs; }

    // Setters
    public void setLogs(List<LogEntry> logs) { this.logs = logs; }
    public void setTotalCount(int totalCount) { this.totalCount = totalCount; }
    public void setQueryTimeMs(int queryTimeMs) { this.queryTimeMs = queryTimeMs; }
}
