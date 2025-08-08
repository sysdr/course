import React, { useState, useEffect } from 'react';
import {
  AppBar,
  Toolbar,
  Typography,
  Container,
  Grid,
  Card,
  CardContent,
  Table,
  TableBody,
  TableCell,
  TableContainer,
  TableHead,
  TableRow,
  Paper,
  Chip,
  Box,
  Button,
  Dialog,
  DialogTitle,
  DialogContent,
  TextField,
  FormControl,
  InputLabel,
  Select,
  MenuItem
} from '@mui/material';
import { LineChart, Line, XAxis, YAxis, CartesianGrid, Tooltip, ResponsiveContainer } from 'recharts';
import axios from 'axios';

function App() {
  const [stats, setStats] = useState({});
  const [subscriptions, setSubscriptions] = useState([]);
  const [deliveryData, setDeliveryData] = useState([]);
  const [open, setOpen] = useState(false);
  const [newSubscription, setNewSubscription] = useState({
    name: '',
    url: '',
    events: [],
    filters: {}
  });

  useEffect(() => {
    fetchData();
    const interval = setInterval(fetchData, 5000);
    return () => clearInterval(interval);
  }, []);

  const fetchData = async () => {
    try {
      const [statsResponse, subscriptionsResponse] = await Promise.all([
        axios.get('/api/v1/stats'),
        axios.get('/api/v1/subscriptions')
      ]);
      
      setStats(statsResponse.data);
      setSubscriptions(subscriptionsResponse.data);
      
      // Update delivery chart data
      const now = new Date();
      setDeliveryData(prev => [
        ...prev.slice(-10),
        {
          time: now.toLocaleTimeString(),
          delivered: statsResponse.data.delivery_stats?.delivered || 0,
          failed: statsResponse.data.delivery_stats?.failed || 0
        }
      ]);
    } catch (error) {
      console.error('Error fetching data:', error);
    }
  };

  const handleCreateSubscription = async () => {
    try {
      if (!newSubscription.name || !newSubscription.url || !newSubscription.events.length) {
        alert('Please fill in all required fields (name, URL, and at least one event type)');
        return;
      }
      const response = await axios.post('/api/v1/subscriptions', newSubscription);
      setOpen(false);
      setNewSubscription({ name: '', url: '', events: [], filters: {} });
      fetchData();
      alert('Subscription created successfully!');
    } catch (error) {
      console.error('Error creating subscription:', error);
      alert('Failed to create subscription: ' + (error.response?.data?.detail || error.message));
    }
  };

  const handleSendTestEvent = async (subscription = null) => {
    // If subscription is provided, use its first event type, otherwise use default
    const eventType = subscription ? subscription.events[0] : 'log.error';
    const testEvent = {
      level: eventType.split('.')[1].toUpperCase(),
      source: 'test-service',
      message: `Test webhook event for ${subscription ? subscription.name : 'all subscriptions'}`,
      event_type: eventType,
      metadata: { 
        test: true,
        subscription_id: subscription?.id,
        timestamp: new Date().toISOString()
      }
    };
    
    try {
      await axios.post('/api/v1/events', testEvent);
      alert('Test event sent successfully! Check your webhook endpoint for the delivery.');
    } catch (error) {
      console.error('Error sending test event:', error);
      alert('Failed to send test event: ' + (error.response?.data?.detail || error.message));
    }
  };

  return (
    <div>
      <AppBar position="static" sx={{ bgcolor: '#1976d2' }}>
        <Toolbar>
          <Typography variant="h6">
            🔔 Webhook Notifications Dashboard
          </Typography>
        </Toolbar>
      </AppBar>

      <Container maxWidth="lg" sx={{ mt: 4, mb: 4 }}>
        <Grid container spacing={3}>
          {/* Stats Cards */}
          <Grid item xs={12} sm={6} md={3}>
            <Card>
              <CardContent>
                <Typography color="textSecondary" gutterBottom>
                  Total Subscriptions
                </Typography>
                <Typography variant="h4">
                  {stats.total_subscriptions || 0}
                </Typography>
              </CardContent>
            </Card>
          </Grid>
          
          <Grid item xs={12} sm={6} md={3}>
            <Card>
              <CardContent>
                <Typography color="textSecondary" gutterBottom>
                  Active Subscriptions
                </Typography>
                <Typography variant="h4">
                  {stats.active_subscriptions || 0}
                </Typography>
              </CardContent>
            </Card>
          </Grid>
          
          <Grid item xs={12} sm={6} md={3}>
            <Card>
              <CardContent>
                <Typography color="textSecondary" gutterBottom>
                  Total Deliveries
                </Typography>
                <Typography variant="h4">
                  {stats.delivery_stats?.total_deliveries || 0}
                </Typography>
              </CardContent>
            </Card>
          </Grid>
          
          <Grid item xs={12} sm={6} md={3}>
            <Card>
              <CardContent>
                <Typography color="textSecondary" gutterBottom>
                  Success Rate
                </Typography>
                <Typography variant="h4">
                  {(stats.delivery_stats?.success_rate || 0).toFixed(1)}%
                </Typography>
              </CardContent>
            </Card>
          </Grid>

          {/* Delivery Chart */}
          <Grid item xs={12} md={8}>
            <Card>
              <CardContent>
                <Typography variant="h6" gutterBottom>
                  Webhook Deliveries Over Time
                </Typography>
                <ResponsiveContainer width="100%" height={300}>
                  <LineChart data={deliveryData}>
                    <CartesianGrid strokeDasharray="3 3" />
                    <XAxis dataKey="time" />
                    <YAxis />
                    <Tooltip />
                    <Line type="monotone" dataKey="delivered" stroke="#8884d8" />
                    <Line type="monotone" dataKey="failed" stroke="#82ca9d" />
                  </LineChart>
                </ResponsiveContainer>
              </CardContent>
            </Card>
          </Grid>

          {/* Actions */}
          <Grid item xs={12} md={4}>
            <Card>
              <CardContent>
                <Typography variant="h6" gutterBottom>
                  Actions
                </Typography>
                <Box sx={{ '& button': { m: 1, display: 'block', width: '100%' } }}>
                  <Button 
                    variant="contained" 
                    onClick={() => setOpen(true)}
                  >
                    Create Subscription
                  </Button>
                  <Button 
                    variant="outlined" 
                    onClick={handleSendTestEvent}
                  >
                    Send Test Event
                  </Button>
                  <Button 
                    variant="outlined" 
                    onClick={fetchData}
                  >
                    Refresh Data
                  </Button>
                </Box>
              </CardContent>
            </Card>
          </Grid>

          {/* Subscriptions Table */}
          <Grid item xs={12}>
            <Card>
              <CardContent>
                <Typography variant="h6" gutterBottom>
                  Webhook Subscriptions
                </Typography>
                <TableContainer>
                  <Table>
                    <TableHead>
                      <TableRow>
                        <TableCell>Name</TableCell>
                        <TableCell>URL</TableCell>
                        <TableCell>Events</TableCell>
                        <TableCell>Status</TableCell>
                        <TableCell>Created</TableCell>
                        <TableCell>Actions</TableCell>
                      </TableRow>
                    </TableHead>
                    <TableBody>
                      {subscriptions.map((subscription) => (
                        <TableRow key={subscription.id}>
                          <TableCell>{subscription.name}</TableCell>
                          <TableCell>{subscription.url}</TableCell>
                          <TableCell>
                            {subscription.events.map((event, index) => (
                              <Chip 
                                key={index} 
                                label={event} 
                                size="small" 
                                sx={{ mr: 0.5, mb: 0.5 }}
                              />
                            ))}
                          </TableCell>
                          <TableCell>
                            <Chip 
                              label={subscription.active ? 'Active' : 'Inactive'}
                              color={subscription.active ? 'success' : 'default'}
                              size="small"
                            />
                          </TableCell>
                          <TableCell>
                            {new Date(subscription.created_at).toLocaleDateString()}
                          </TableCell>
                          <TableCell>
                            <Button
                              variant="outlined"
                              size="small"
                              onClick={() => handleSendTestEvent(subscription)}
                            >
                              Test
                            </Button>
                          </TableCell>
                        </TableRow>
                      ))}
                    </TableBody>
                  </Table>
                </TableContainer>
              </CardContent>
            </Card>
          </Grid>
        </Grid>
      </Container>

      {/* Create Subscription Dialog */}
      <Dialog open={open} onClose={() => setOpen(false)} maxWidth="sm" fullWidth>
        <DialogTitle>Create New Webhook Subscription</DialogTitle>
        <DialogContent>
          <TextField
            fullWidth
            label="Name"
            value={newSubscription.name}
            onChange={(e) => setNewSubscription({...newSubscription, name: e.target.value})}
            margin="dense"
          />
          <TextField
            fullWidth
            label="Webhook URL"
            value={newSubscription.url}
            onChange={(e) => setNewSubscription({...newSubscription, url: e.target.value})}
            margin="dense"
          />
          <FormControl fullWidth margin="dense">
            <InputLabel>Event Types</InputLabel>
            <Select
              multiple
              value={newSubscription.events}
              onChange={(e) => setNewSubscription({...newSubscription, events: e.target.value})}
            >
              <MenuItem value="log.critical">Critical</MenuItem>
              <MenuItem value="log.error">Error</MenuItem>
              <MenuItem value="log.warning">Warning</MenuItem>
              <MenuItem value="log.info">Info</MenuItem>
            </Select>
          </FormControl>
          <Box sx={{ mt: 2 }}>
            <Button onClick={handleCreateSubscription} variant="contained" fullWidth>
              Create Subscription
            </Button>
          </Box>
        </DialogContent>
      </Dialog>
    </div>
  );
}

export default App;
