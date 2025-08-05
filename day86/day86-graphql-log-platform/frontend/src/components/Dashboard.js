import React, { useState, useEffect } from 'react';
import { useQuery } from '@apollo/client';
import {
  Container,
  Grid,
  Paper,
  Typography,
  Box,
  Card,
  CardContent,
  AppBar,
  Toolbar,
  Button,
} from '@mui/material';
import {
  BarChart,
  Bar,
  XAxis,
  YAxis,
  CartesianGrid,
  Tooltip,
  Legend,
  PieChart,
  Pie,
  Cell,
  ResponsiveContainer,
} from 'recharts';
import { useNavigate } from 'react-router-dom';

import { GET_LOG_STATS, GET_SERVICES } from '../queries/logQueries';

const COLORS = ['#0088FE', '#00C49F', '#FFBB28', '#FF8042'];

function Dashboard() {
  const navigate = useNavigate();
  const { data: statsData, loading: statsLoading } = useQuery(GET_LOG_STATS);
  const { data: servicesData } = useQuery(GET_SERVICES);

  const pieData = statsData ? [
    { name: 'Info', value: statsData.logStats.infoCount },
    { name: 'Warning', value: statsData.logStats.warningCount },
    { name: 'Error', value: statsData.logStats.errorCount },
  ] : [];

  const barData = servicesData ? servicesData.services.map((service, index) => ({
    service,
    logs: Math.floor(Math.random() * 1000) + 100,
  })) : [];

  return (
    <Box sx={{ flexGrow: 1 }}>
      <AppBar position="static">
        <Toolbar>
          <Typography variant="h6" component="div" sx={{ flexGrow: 1 }}>
            GraphQL Log Platform Dashboard
          </Typography>
          <Button color="inherit" onClick={() => navigate('/logs')}>
            Log Viewer
          </Button>
          <Button color="inherit" onClick={() => navigate('/stream')}>
            Real-time Stream
          </Button>
        </Toolbar>
      </AppBar>

      <Container maxWidth="lg" sx={{ mt: 4, mb: 4 }}>
        <Grid container spacing={3}>
          {/* Stats Cards */}
          <Grid item xs={12} sm={6} md={3}>
            <Paper
              sx={{
                p: 2,
                display: 'flex',
                flexDirection: 'column',
                height: 140,
              }}
            >
              <Typography component="h2" variant="h6" color="primary" gutterBottom>
                Total Logs
              </Typography>
              <Typography component="p" variant="h4">
                {statsData?.logStats.totalLogs || 0}
              </Typography>
            </Paper>
          </Grid>
          
          <Grid item xs={12} sm={6} md={3}>
            <Paper
              sx={{
                p: 2,
                display: 'flex',
                flexDirection: 'column',
                height: 140,
              }}
            >
              <Typography component="h2" variant="h6" color="error" gutterBottom>
                Errors
              </Typography>
              <Typography component="p" variant="h4">
                {statsData?.logStats.errorCount || 0}
              </Typography>
            </Paper>
          </Grid>

          <Grid item xs={12} sm={6} md={3}>
            <Paper
              sx={{
                p: 2,
                display: 'flex',
                flexDirection: 'column',
                height: 140,
              }}
            >
              <Typography component="h2" variant="h6" color="warning" gutterBottom>
                Warnings
              </Typography>
              <Typography component="p" variant="h4">
                {statsData?.logStats.warningCount || 0}
              </Typography>
            </Paper>
          </Grid>

          <Grid item xs={12} sm={6} md={3}>
            <Paper
              sx={{
                p: 2,
                display: 'flex',
                flexDirection: 'column',
                height: 140,
              }}
            >
              <Typography component="h2" variant="h6" color="success" gutterBottom>
                Services
              </Typography>
              <Typography component="p" variant="h4">
                {servicesData?.services.length || 0}
              </Typography>
            </Paper>
          </Grid>

          {/* Log Level Distribution */}
          <Grid item xs={12} md={6}>
            <Paper sx={{ p: 2 }}>
              <Typography component="h2" variant="h6" color="primary" gutterBottom>
                Log Level Distribution
              </Typography>
              <ResponsiveContainer width="100%" height={300}>
                <PieChart>
                  <Pie
                    data={pieData}
                    cx="50%"
                    cy="50%"
                    labelLine={false}
                    label={({ name, percent }) => `${name} ${(percent * 100).toFixed(0)}%`}
                    outerRadius={80}
                    fill="#8884d8"
                    dataKey="value"
                  >
                    {pieData.map((entry, index) => (
                      <Cell key={`cell-${index}`} fill={COLORS[index % COLORS.length]} />
                    ))}
                  </Pie>
                  <Tooltip />
                </PieChart>
              </ResponsiveContainer>
            </Paper>
          </Grid>

          {/* Service Activity */}
          <Grid item xs={12} md={6}>
            <Paper sx={{ p: 2 }}>
              <Typography component="h2" variant="h6" color="primary" gutterBottom>
                Service Activity
              </Typography>
              <ResponsiveContainer width="100%" height={300}>
                <BarChart data={barData}>
                  <CartesianGrid strokeDasharray="3 3" />
                  <XAxis dataKey="service" />
                  <YAxis />
                  <Tooltip />
                  <Legend />
                  <Bar dataKey="logs" fill="#8884d8" />
                </BarChart>
              </ResponsiveContainer>
            </Paper>
          </Grid>
        </Grid>
      </Container>
    </Box>
  );
}

export default Dashboard;
