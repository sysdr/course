import React, { useState, useEffect } from 'react';
import { useSubscription } from '@apollo/client';
import {
  Container,
  Paper,
  List,
  ListItem,
  ListItemText,
  Typography,
  Box,
  Chip,
  AppBar,
  Toolbar,
  Button,
  FormControl,
  InputLabel,
  Select,
  MenuItem,
} from '@mui/material';
import { useNavigate } from 'react-router-dom';

import { LOG_STREAM_SUBSCRIPTION, ERROR_ALERTS_SUBSCRIPTION } from '../queries/logQueries';

function RealTimeStream() {
  const navigate = useNavigate();
  const [filter, setFilter] = useState({ service: '', level: '' });
  const [logs, setLogs] = useState([]);

  const { data: streamData } = useSubscription(LOG_STREAM_SUBSCRIPTION, {
    variables: filter,
  });

  const { data: errorData } = useSubscription(ERROR_ALERTS_SUBSCRIPTION);

  useEffect(() => {
    if (streamData?.logStream) {
      setLogs(prev => [streamData.logStream, ...prev.slice(0, 99)]);
    }
  }, [streamData]);

  useEffect(() => {
    if (errorData?.errorAlerts) {
      setLogs(prev => [errorData.errorAlerts, ...prev.slice(0, 99)]);
    }
  }, [errorData]);

  const getLevelColor = (level) => {
    switch (level) {
      case 'ERROR':
        return 'error';
      case 'WARNING':
        return 'warning';
      case 'INFO':
        return 'info';
      default:
        return 'default';
    }
  };

  return (
    <Box sx={{ flexGrow: 1 }}>
      <AppBar position="static">
        <Toolbar>
          <Typography variant="h6" component="div" sx={{ flexGrow: 1 }}>
            Real-time Log Stream
          </Typography>
          <Button color="inherit" onClick={() => navigate('/')}>
            Dashboard
          </Button>
          <Button color="inherit" onClick={() => navigate('/logs')}>
            Log Viewer
          </Button>
        </Toolbar>
      </AppBar>

      <Container maxWidth="lg" sx={{ mt: 4, mb: 4 }}>
        {/* Filters */}
        <Paper sx={{ p: 2, mb: 2 }}>
          <Box sx={{ display: 'flex', gap: 2 }}>
            <FormControl sx={{ minWidth: 150 }}>
              <InputLabel>Filter by Service</InputLabel>
              <Select
                value={filter.service}
                label="Filter by Service"
                onChange={(e) => setFilter({ ...filter, service: e.target.value })}
              >
                <MenuItem value="">All Services</MenuItem>
                <MenuItem value="api-gateway">API Gateway</MenuItem>
                <MenuItem value="user-service">User Service</MenuItem>
                <MenuItem value="order-service">Order Service</MenuItem>
                <MenuItem value="payment-service">Payment Service</MenuItem>
              </Select>
            </FormControl>

            <FormControl sx={{ minWidth: 120 }}>
              <InputLabel>Filter by Level</InputLabel>
              <Select
                value={filter.level}
                label="Filter by Level"
                onChange={(e) => setFilter({ ...filter, level: e.target.value })}
              >
                <MenuItem value="">All Levels</MenuItem>
                <MenuItem value="INFO">Info</MenuItem>
                <MenuItem value="WARNING">Warning</MenuItem>
                <MenuItem value="ERROR">Error</MenuItem>
              </Select>
            </FormControl>
          </Box>
        </Paper>

        {/* Live Logs */}
        <Paper sx={{ height: 600, overflow: 'auto' }}>
          <List>
            {logs.map((log, index) => (
              <ListItem key={`${log.id}-${index}`} divider>
                <ListItemText
                  primary={
                    <Box sx={{ display: 'flex', alignItems: 'center', gap: 1 }}>
                      <Typography variant="body2" color="text.secondary">
                        {new Date(log.timestamp).toLocaleTimeString()}
                      </Typography>
                      <Chip
                        label={log.service}
                        size="small"
                        variant="outlined"
                      />
                      <Chip
                        label={log.level}
                        color={getLevelColor(log.level)}
                        size="small"
                      />
                    </Box>
                  }
                  secondary={
                    <Box>
                      <Typography variant="body1" sx={{ mt: 1 }}>
                        {log.message}
                      </Typography>
                      <Typography variant="caption" color="text.secondary">
                        Trace: {log.traceId}
                      </Typography>
                    </Box>
                  }
                />
              </ListItem>
            ))}
          </List>
        </Paper>
      </Container>
    </Box>
  );
}

export default RealTimeStream;
