/**
 * LogPlatform JavaScript SDK
 * Official client library for the distributed log processing platform
 */

export { LogPlatformClient } from './client';
export { Config } from './config';
export { LogPlatformError, ConnectionError, AuthenticationError } from './exceptions';
export { LogEntry, QueryResult, StreamConfig, SubmitResponse } from './types';
