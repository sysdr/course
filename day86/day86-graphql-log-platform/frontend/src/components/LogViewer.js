import React, { useState } from 'react';
import { useQuery } from '@apollo/client';
import {
  Container,
  Paper,
  Table,
  TableBody,
  TableCell,
  TableContainer,
  TableHead,
  TableRow,
  TextField,
  FormControl,
  InputLabel,
  Select,
  MenuItem,
  Box,
  Typography,
  Chip,
  AppBar,
  Toolbar,
  Button,
} from '@mui/material';
import { useNavigate } from 'react-router-dom';

import { GET_LOGS, GET_SERVICES } from '../queries/logQueries';

const getLevelColor = (level) => {
  switch (level) {
    case 'ERROR':
      return 'error';
    case 'WARNING':
      return 'warning';
    case 'INFO':
      return 'info';
    case 'DEBUG':
      return 'default';
    default:
      return 'default';
  }
};

function LogViewer() {
  const navigate = useNavigate();
  const [filters, setFilters] = useState({
    service: '',
    level: '',
    searchText: '',
    limit: 20,
  });

  const { data: logsData, loading, refetch } = useQuery(GET_LOGS, {
    variables: { filters },
  });
  
  const { data: servicesData } = useQuery(GET_SERVICES);

  const handleFilterChange = (field, value) => {
    const newFilters = { ...filters, [field]: value };
    setFilters(newFilters);
    refetch({ filters: newFilters });
  };

  return (
    <Box sx={{ flexGrow: 1 }}>
      <AppBar position="static">
        <Toolbar>
          <Typography variant="h6" component="div" sx={{ flexGrow: 1 }}>
            Log Viewer
          </Typography>
          <Button color="inherit" onClick={() => navigate('/')}>
            Dashboard
          </Button>
          <Button color="inherit" onClick={() => navigate('/stream')}>
            Real-time Stream
          </Button>
        </Toolbar>
      </AppBar>

      <Container maxWidth="lg" sx={{ mt: 4, mb: 4 }}>
        {/* Filters */}
        <Paper sx={{ p: 2, mb: 2 }}>
          <Box sx={{ display: 'flex', gap: 2, flexWrap: 'wrap' }}>
            <TextField
              label="Search"
              value={filters.searchText}
              onChange={(e) => handleFilterChange('searchText', e.target.value)}
              sx={{ minWidth: 200 }}
            />
            
            <FormControl sx={{ minWidth: 150 }}>
              <InputLabel>Service</InputLabel>
              <Select
                value={filters.service}
                label="Service"
                onChange={(e) => handleFilterChange('service', e.target.value)}
              >
                <MenuItem value="">All Services</MenuItem>
                {servicesData?.services.map((service) => (
                  <MenuItem key={service} value={service}>
                    {service}
                  </MenuItem>
                ))}
              </Select>
            </FormControl>

            <FormControl sx={{ minWidth: 120 }}>
              <InputLabel>Level</InputLabel>
              <Select
                value={filters.level}
                label="Level"
                onChange={(e) => handleFilterChange('level', e.target.value)}
              >
                <MenuItem value="">All Levels</MenuItem>
                <MenuItem value="DEBUG">Debug</MenuItem>
                <MenuItem value="INFO">Info</MenuItem>
                <MenuItem value="WARNING">Warning</MenuItem>
                <MenuItem value="ERROR">Error</MenuItem>
              </Select>
            </FormControl>
          </Box>
        </Paper>

        {/* Logs Table */}
        <TableContainer component={Paper}>
          <Table sx={{ minWidth: 650 }}>
            <TableHead>
              <TableRow>
                <TableCell>Timestamp</TableCell>
                <TableCell>Service</TableCell>
                <TableCell>Level</TableCell>
                <TableCell>Message</TableCell>
                <TableCell>Trace ID</TableCell>
              </TableRow>
            </TableHead>
            <TableBody>
              {logsData?.logs.map((log) => (
                <TableRow key={log.id}>
                  <TableCell>
                    {new Date(log.timestamp).toLocaleString()}
                  </TableCell>
                  <TableCell>{log.service}</TableCell>
                  <TableCell>
                    <Chip
                      label={log.level}
                      color={getLevelColor(log.level)}
                      size="small"
                    />
                  </TableCell>
                  <TableCell sx={{ maxWidth: 400 }}>{log.message}</TableCell>
                  <TableCell>
                    <Typography variant="body2" color="text.secondary">
                      {log.traceId}
                    </Typography>
                  </TableCell>
                </TableRow>
              ))}
            </TableBody>
          </Table>
        </TableContainer>
      </Container>
    </Box>
  );
}

export default LogViewer;
