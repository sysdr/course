import { gql } from '@apollo/client';

export const GET_LOGS = gql`
  query GetLogs($filters: LogFilterInput) {
    logs(filters: $filters) {
      id
      timestamp
      service
      level
      message
      metadata
      traceId
      spanId
    }
  }
`;

export const GET_LOG_STATS = gql`
  query GetLogStats($startTime: DateTime, $endTime: DateTime) {
    logStats(startTime: $startTime, endTime: $endTime) {
      totalLogs
      errorCount
      warningCount
      infoCount
      services
      timeRange
    }
  }
`;

export const GET_SERVICES = gql`
  query GetServices {
    services
  }
`;

export const CREATE_LOG = gql`
  mutation CreateLog($logData: LogCreateInput!) {
    createLog(logData: $logData) {
      id
      timestamp
      service
      level
      message
      traceId
    }
  }
`;

export const LOG_STREAM_SUBSCRIPTION = gql`
  subscription LogStream($service: String, $level: String) {
    logStream(service: $service, level: $level) {
      id
      timestamp
      service
      level
      message
      metadata
      traceId
    }
  }
`;

export const ERROR_ALERTS_SUBSCRIPTION = gql`
  subscription ErrorAlerts {
    errorAlerts {
      id
      timestamp
      service
      level
      message
      traceId
    }
  }
`;
