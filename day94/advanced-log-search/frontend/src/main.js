class AdvancedLogSearch {
    constructor() {
        this.apiBase = window.location.origin;
        this.ws = null;
        this.currentPage = 1;
        this.pageSize = 100;
        this.totalResults = 0;
        this.currentFilters = {};
        this.searchHistory = JSON.parse(localStorage.getItem('searchHistory') || '[]');
        this.debounceTimer = null;
        
        this.init();
    }

    async init() {
        await this.loadFilterOptions();
        this.setupEventListeners();
        this.connectWebSocket();
        this.renderSearchHistory();
        this.setDefaultTimeRange();
    }

    async loadFilterOptions() {
        try {
            const response = await fetch(`${this.apiBase}/api/filters`);
            const options = await response.json();
            
            this.renderFilterOptions('level-filters', options.levels, 'levels');
            this.renderFilterOptions('service-filters', options.services, 'services');
        } catch (error) {
            console.error('Failed to load filter options:', error);
        }
    }

    renderFilterOptions(containerId, options, filterType) {
        const container = document.getElementById(containerId);
        container.innerHTML = '';
        
        options.forEach(option => {
            const label = document.createElement('label');
            label.innerHTML = `
                <input type="checkbox" name="${filterType}" value="${option}">
                <span>${option}</span>
            `;
            container.appendChild(label);
        });
    }

    setupEventListeners() {
        // Search input with debouncing
        document.getElementById('search-input').addEventListener('input', (e) => {
            clearTimeout(this.debounceTimer);
            this.debounceTimer = setTimeout(() => {
                this.performSearch();
            }, 300);
        });

        // Search button
        document.getElementById('search-btn').addEventListener('click', () => {
            this.performSearch();
        });

        // Clear button
        document.getElementById('clear-btn').addEventListener('click', () => {
            this.clearSearch();
        });

        // Filter application
        document.getElementById('apply-filters').addEventListener('click', () => {
            this.performSearch();
        });

        // Reset filters
        document.getElementById('reset-filters').addEventListener('click', () => {
            this.resetFilters();
        });

        // Save search
        document.getElementById('save-search').addEventListener('click', () => {
            this.saveCurrentSearch();
        });

        // Time range selection
        document.getElementById('time-range').addEventListener('change', (e) => {
            const customRange = document.getElementById('custom-time-range');
            customRange.style.display = e.target.value === 'custom' ? 'flex' : 'none';
        });

        // Sorting changes
        document.getElementById('sort-by').addEventListener('change', () => {
            this.performSearch();
        });

        document.getElementById('sort-order').addEventListener('change', () => {
            this.performSearch();
        });

        // Export results
        document.getElementById('export-results').addEventListener('click', () => {
            this.exportResults();
        });

        // Pagination
        document.getElementById('prev-page').addEventListener('click', () => {
            if (this.currentPage > 1) {
                this.currentPage--;
                this.performSearch();
            }
        });

        document.getElementById('next-page').addEventListener('click', () => {
            const maxPage = Math.ceil(this.totalResults / this.pageSize);
            if (this.currentPage < maxPage) {
                this.currentPage++;
                this.performSearch();
            }
        });

        // Enter key in search
        document.getElementById('search-input').addEventListener('keypress', (e) => {
            if (e.key === 'Enter') {
                this.performSearch();
            }
        });
    }

    connectWebSocket() {
        const protocol = window.location.protocol === 'https:' ? 'wss:' : 'ws:';
        this.ws = new WebSocket(`${protocol}//${window.location.host}/ws`);

        this.ws.onopen = () => {
            console.log('WebSocket connected');
            document.getElementById('connection-status').textContent = '🟢 Connected';
            
            // Send ping every 30 seconds to keep connection alive
            setInterval(() => {
                if (this.ws.readyState === WebSocket.OPEN) {
                    this.ws.send(JSON.stringify({ type: 'ping' }));
                }
            }, 30000);
        };

        this.ws.onmessage = (event) => {
            const message = JSON.parse(event.data);
            
            if (message.type === 'new_log') {
                this.handleNewLog(message.data);
            }
        };

        this.ws.onclose = () => {
            console.log('WebSocket disconnected');
            document.getElementById('connection-status').textContent = '🔴 Disconnected';
            
            // Attempt to reconnect after 5 seconds
            setTimeout(() => {
                this.connectWebSocket();
            }, 5000);
        };

        this.ws.onerror = (error) => {
            console.error('WebSocket error:', error);
            document.getElementById('connection-status').textContent = '⚠️ Error';
        };
    }

    handleNewLog(logData) {
        // If we're currently searching, check if new log matches current filters
        const searchQuery = document.getElementById('search-input').value.toLowerCase();
        
        if (this.logMatchesCurrentSearch(logData, searchQuery)) {
            this.prependLogEntry(logData, true);
        }
    }

    logMatchesCurrentSearch(logData, searchQuery) {
        // Simple matching logic - in production, this would be more sophisticated
        if (searchQuery && !logData.message.toLowerCase().includes(searchQuery)) {
            return false;
        }

        // Check level filters
        const levelFilters = this.getSelectedFilters('levels');
        if (levelFilters.length > 0 && !levelFilters.includes(logData.level)) {
            return false;
        }

        // Check service filters
        const serviceFilters = this.getSelectedFilters('services');
        if (serviceFilters.length > 0 && !serviceFilters.includes(logData.service)) {
            return false;
        }

        return true;
    }

    async performSearch() {
        const searchQuery = document.getElementById('search-input').value;
        this.currentFilters = this.collectFilters();
        
        const searchRequest = {
            query: searchQuery,
            filters: this.currentFilters,
            limit: this.pageSize,
            offset: (this.currentPage - 1) * this.pageSize,
            sort_by: document.getElementById('sort-by').value,
            sort_order: document.getElementById('sort-order').value
        };

        try {
            this.showLoading();
            
            const response = await fetch(`${this.apiBase}/api/search`, {
                method: 'POST',
                headers: {
                    'Content-Type': 'application/json',
                },
                body: JSON.stringify(searchRequest)
            });

            if (!response.ok) {
                throw new Error('Search failed');
            }

            const results = await response.json();
            this.displayResults(results);
            this.updateSearchStats(results);
            this.updatePagination(results);

            // Save to search history
            if (searchQuery.trim() || Object.keys(this.currentFilters).length > 0) {
                this.addToSearchHistory(searchQuery, this.currentFilters);
            }

        } catch (error) {
            console.error('Search error:', error);
            this.showError('Search failed. Please try again.');
        }
    }

    collectFilters() {
        const filters = {};

        // Level filters
        const levels = this.getSelectedFilters('levels');
        if (levels.length > 0) {
            filters.levels = levels;
        }

        // Service filters
        const services = this.getSelectedFilters('services');
        if (services.length > 0) {
            filters.services = services;
        }

        // Time range
        const timeRange = document.getElementById('time-range').value;
        if (timeRange && timeRange !== '') {
            if (timeRange === 'custom') {
                const startTime = document.getElementById('start-time').value;
                const endTime = document.getElementById('end-time').value;
                if (startTime || endTime) {
                    filters.time_range = {};
                    if (startTime) filters.time_range.start = startTime;
                    if (endTime) filters.time_range.end = endTime;
                }
            } else {
                const now = new Date();
                const start = new Date(now);
                
                switch (timeRange) {
                    case '1h':
                        start.setHours(now.getHours() - 1);
                        break;
                    case '24h':
                        start.setDate(now.getDate() - 1);
                        break;
                    case '7d':
                        start.setDate(now.getDate() - 7);
                        break;
                }
                
                filters.time_range = {
                    start: start.toISOString(),
                    end: now.toISOString()
                };
            }
        }

        // User ID filter
        const userId = document.getElementById('user-id-filter').value.trim();
        if (userId) {
            filters.user_id = userId;
        }

        // Source IP filter
        const sourceIp = document.getElementById('source-ip-filter').value.trim();
        if (sourceIp) {
            filters.source_ip = sourceIp;
        }

        return filters;
    }

    getSelectedFilters(filterType) {
        const checkboxes = document.querySelectorAll(`input[name="${filterType}"]:checked`);
        return Array.from(checkboxes).map(cb => cb.value);
    }

    showLoading() {
        const resultsList = document.getElementById('results-list');
        resultsList.innerHTML = '<div class="loading">Searching...</div>';
    }

    showError(message) {
        const resultsList = document.getElementById('results-list');
        resultsList.innerHTML = `<div class="error-message">${message}</div>`;
    }

    displayResults(results) {
        const resultsList = document.getElementById('results-list');
        
        if (results.logs.length === 0) {
            resultsList.innerHTML = `
                <div class="welcome-message">
                    <h3>📭 No results found</h3>
                    <p>Try adjusting your search criteria or filters.</p>
                </div>
            `;
            return;
        }

        resultsList.innerHTML = '';
        results.logs.forEach(log => {
            this.appendLogEntry(log);
        });

        this.totalResults = results.total_count;
    }

    appendLogEntry(log) {
        const logEntry = this.createLogEntryElement(log);
        document.getElementById('results-list').appendChild(logEntry);
    }

    prependLogEntry(log, isNew = false) {
        const logEntry = this.createLogEntryElement(log);
        if (isNew) {
            logEntry.classList.add('new-log');
        }
        
        const resultsList = document.getElementById('results-list');
        const firstChild = resultsList.firstChild;
        
        if (firstChild && firstChild.classList && firstChild.classList.contains('welcome-message')) {
            resultsList.innerHTML = '';
        }
        
        resultsList.insertBefore(logEntry, resultsList.firstChild);
    }

    createLogEntryElement(log) {
        const logEntry = document.createElement('div');
        logEntry.className = 'log-entry';
        
        const timestamp = new Date(log.timestamp).toLocaleString();
        const levelClass = log.level.toLowerCase();
        
        logEntry.innerHTML = `
            <div class="log-header">
                <div class="log-meta">
                    <span class="log-level ${levelClass}">${log.level}</span>
                    <span>📅 ${timestamp}</span>
                    <span>🔧 ${log.service}</span>
                    ${log.user_id ? `<span>👤 ${log.user_id}</span>` : ''}
                    ${log.source_ip ? `<span>🌐 ${log.source_ip}</span>` : ''}
                    ${log.request_id ? `<span>🔗 ${log.request_id}</span>` : ''}
                </div>
                <div class="log-id">#${log.id}</div>
            </div>
            <div class="log-message">${this.escapeHtml(log.message)}</div>
            ${log.metadata ? `<details><summary>Metadata</summary><pre>${JSON.stringify(log.metadata, null, 2)}</pre></details>` : ''}
        `;
        
        return logEntry;
    }

    escapeHtml(text) {
        const div = document.createElement('div');
        div.textContent = text;
        return div.innerHTML;
    }

    updateSearchStats(results) {
        const statsElement = document.getElementById('search-stats');
        const resultsInfo = document.getElementById('results-info');
        
        const stats = `${results.logs.length} of ${results.total_count} results (${results.execution_time_ms.toFixed(1)}ms)`;
        statsElement.textContent = stats;
        resultsInfo.textContent = `Found ${results.total_count} results in ${results.execution_time_ms.toFixed(1)}ms`;
    }

    updatePagination(results) {
        const paginationElement = document.getElementById('pagination');
        const maxPage = Math.ceil(results.total_count / this.pageSize);
        
        if (maxPage <= 1) {
            paginationElement.style.display = 'none';
            return;
        }
        
        paginationElement.style.display = 'flex';
        
        const prevBtn = document.getElementById('prev-page');
        const nextBtn = document.getElementById('next-page');
        const pageInfo = document.getElementById('page-info');
        
        prevBtn.disabled = this.currentPage <= 1;
        nextBtn.disabled = this.currentPage >= maxPage;
        pageInfo.textContent = `Page ${this.currentPage} of ${maxPage}`;
    }

    addToSearchHistory(query, filters) {
        const searchItem = {
            timestamp: new Date().toISOString(),
            query: query,
            filters: filters,
            id: Date.now()
        };

        // Remove duplicates and keep only last 10
        this.searchHistory = this.searchHistory.filter(item => 
            item.query !== query || JSON.stringify(item.filters) !== JSON.stringify(filters)
        );
        
        this.searchHistory.unshift(searchItem);
        this.searchHistory = this.searchHistory.slice(0, 10);
        
        localStorage.setItem('searchHistory', JSON.stringify(this.searchHistory));
        this.renderSearchHistory();
    }

    renderSearchHistory() {
        const historyList = document.getElementById('history-list');
        
        if (this.searchHistory.length === 0) {
            historyList.innerHTML = '<div style="text-align: center; color: #888; font-size: 0.75rem;">No recent searches</div>';
            return;
        }

        historyList.innerHTML = '';
        this.searchHistory.forEach(item => {
            const historyItem = document.createElement('div');
            historyItem.className = 'history-item';
            historyItem.title = 'Click to repeat this search';
            
            const filterSummary = this.getFilterSummary(item.filters);
            const displayText = item.query || 'Advanced filters';
            
            historyItem.innerHTML = `
                <div style="font-weight: 600;">${this.escapeHtml(displayText)}</div>
                ${filterSummary ? `<div style="color: #666; font-size: 0.7rem;">${filterSummary}</div>` : ''}
                <div style="color: #888; font-size: 0.7rem;">${new Date(item.timestamp).toLocaleString()}</div>
            `;
            
            historyItem.addEventListener('click', () => {
                this.loadSearchFromHistory(item);
            });
            
            historyList.appendChild(historyItem);
        });
    }

    getFilterSummary(filters) {
        const parts = [];
        
        if (filters.levels) {
            parts.push(`Levels: ${filters.levels.join(', ')}`);
        }
        
        if (filters.services) {
            parts.push(`Services: ${filters.services.join(', ')}`);
        }
        
        if (filters.time_range) {
            parts.push('Time range applied');
        }
        
        if (filters.user_id) {
            parts.push(`User: ${filters.user_id}`);
        }
        
        if (filters.source_ip) {
            parts.push(`IP: ${filters.source_ip}`);
        }
        
        return parts.join(' | ');
    }

    loadSearchFromHistory(searchItem) {
        // Set search query
        document.getElementById('search-input').value = searchItem.query || '';
        
        // Reset filters first
        this.resetFilters();
        
        // Apply saved filters
        const filters = searchItem.filters;
        
        if (filters.levels) {
            filters.levels.forEach(level => {
                const checkbox = document.querySelector(`input[name="levels"][value="${level}"]`);
                if (checkbox) checkbox.checked = true;
            });
        }
        
        if (filters.services) {
            filters.services.forEach(service => {
                const checkbox = document.querySelector(`input[name="services"][value="${service}"]`);
                if (checkbox) checkbox.checked = true;
            });
        }
        
        if (filters.user_id) {
            document.getElementById('user-id-filter').value = filters.user_id;
        }
        
        if (filters.source_ip) {
            document.getElementById('source-ip-filter').value = filters.source_ip;
        }
        
        // Perform the search
        this.currentPage = 1;
        this.performSearch();
    }

    clearSearch() {
        document.getElementById('search-input').value = '';
        this.resetFilters();
        
        const resultsList = document.getElementById('results-list');
        resultsList.innerHTML = `
            <div class="welcome-message">
                <h3>🚀 Welcome to Advanced Log Search</h3>
                <p>Use the search bar above to find log entries. Apply filters to narrow down results.</p>
                <ul>
                    <li>Search for text: <code>error timeout</code></li>
                    <li>Use filters to narrow results by level, service, time</li>
                    <li>Results update in real-time as new logs arrive</li>
                    <li>Export filtered results in multiple formats</li>
                </ul>
            </div>
        `;
        
        document.getElementById('pagination').style.display = 'none';
        document.getElementById('search-stats').textContent = '';
        document.getElementById('results-info').textContent = 'Ready to search...';
    }

    resetFilters() {
        // Clear all checkboxes
        document.querySelectorAll('input[type="checkbox"]').forEach(cb => cb.checked = false);
        
        // Reset selects and inputs
        document.getElementById('time-range').value = '';
        document.getElementById('user-id-filter').value = '';
        document.getElementById('source-ip-filter').value = '';
        document.getElementById('start-time').value = '';
        document.getElementById('end-time').value = '';
        document.getElementById('custom-time-range').style.display = 'none';
        
        // Reset sorting
        document.getElementById('sort-by').value = 'timestamp';
        document.getElementById('sort-order').value = 'desc';
        
        this.currentPage = 1;
    }

    saveCurrentSearch() {
        const query = document.getElementById('search-input').value;
        const filters = this.collectFilters();
        
        if (!query.trim() && Object.keys(filters).length === 0) {
            alert('Please enter a search query or apply filters before saving.');
            return;
        }
        
        const name = prompt('Enter a name for this saved search:', query || 'Advanced Search');
        if (name) {
            const savedSearches = JSON.parse(localStorage.getItem('savedSearches') || '[]');
            savedSearches.push({
                name: name,
                query: query,
                filters: filters,
                timestamp: new Date().toISOString()
            });
            localStorage.setItem('savedSearches', JSON.stringify(savedSearches));
            alert('Search saved successfully!');
        }
    }

    async exportResults() {
        const format = prompt('Export format:\n1. JSON\n2. CSV\n3. Text\n\nEnter 1, 2, or 3:', '1');
        
        if (!format || !['1', '2', '3'].includes(format)) {
            return;
        }
        
        try {
            // Get all results for export (not just current page)
            const searchRequest = {
                query: document.getElementById('search-input').value,
                filters: this.currentFilters,
                limit: this.totalResults || 10000, // Export all results
                offset: 0,
                sort_by: document.getElementById('sort-by').value,
                sort_order: document.getElementById('sort-order').value
            };

            const response = await fetch(`${this.apiBase}/api/search`, {
                method: 'POST',
                headers: {
                    'Content-Type': 'application/json',
                },
                body: JSON.stringify(searchRequest)
            });

            const results = await response.json();
            
            let content, filename, mimeType;
            
            switch (format) {
                case '1': // JSON
                    content = JSON.stringify(results.logs, null, 2);
                    filename = `log-search-${new Date().toISOString().slice(0, 19)}.json`;
                    mimeType = 'application/json';
                    break;
                    
                case '2': // CSV
                    content = this.convertToCSV(results.logs);
                    filename = `log-search-${new Date().toISOString().slice(0, 19)}.csv`;
                    mimeType = 'text/csv';
                    break;
                    
                case '3': // Text
                    content = results.logs.map(log => 
                        `[${log.timestamp}] ${log.level} ${log.service}: ${log.message}`
                    ).join('\n');
                    filename = `log-search-${new Date().toISOString().slice(0, 19)}.txt`;
                    mimeType = 'text/plain';
                    break;
            }
            
            this.downloadFile(content, filename, mimeType);
            
        } catch (error) {
            console.error('Export error:', error);
            alert('Export failed. Please try again.');
        }
    }

    convertToCSV(logs) {
        const headers = ['timestamp', 'level', 'service', 'message', 'source_ip', 'user_id', 'request_id'];
        const csvContent = [
            headers.join(','),
            ...logs.map(log => headers.map(header => {
                const value = log[header] || '';
                // Escape commas and quotes in CSV
                return `"${String(value).replace(/"/g, '""')}"`;
            }).join(','))
        ];
        
        return csvContent.join('\n');
    }

    downloadFile(content, filename, mimeType) {
        const blob = new Blob([content], { type: mimeType });
        const url = URL.createObjectURL(blob);
        const link = document.createElement('a');
        link.href = url;
        link.download = filename;
        document.body.appendChild(link);
        link.click();
        document.body.removeChild(link);
        URL.revokeObjectURL(url);
    }

    setDefaultTimeRange() {
        // Set default end time to now
        const now = new Date();
        document.getElementById('end-time').value = now.toISOString().slice(0, 19);
        
        // Set default start time to 1 hour ago
        const oneHourAgo = new Date(now.getTime() - 60 * 60 * 1000);
        document.getElementById('start-time').value = oneHourAgo.toISOString().slice(0, 19);
    }
}

// Initialize the application when DOM is loaded
document.addEventListener('DOMContentLoaded', () => {
    new AdvancedLogSearch();
});

// Add some demo functionality for generating test logs
window.generateDemoLogs = async function() {
    const services = ['auth', 'payment', 'user-api', 'inventory', 'notification'];
    const levels = ['INFO', 'WARN', 'ERROR', 'DEBUG'];
    const messages = [
        'User authentication successful',
        'Payment processing completed',
        'Database connection timeout',
        'Invalid request parameters',
        'Cache miss for user data',
        'Rate limit exceeded',
        'Service health check passed',
        'Memory usage threshold reached',
        'Failed to process order',
        'User session expired'
    ];

    for (let i = 0; i < 20; i++) {
        const logData = {
            level: levels[Math.floor(Math.random() * levels.length)],
            service: services[Math.floor(Math.random() * services.length)],
            message: messages[Math.floor(Math.random() * messages.length)],
            source_ip: `192.168.1.${Math.floor(Math.random() * 255)}`,
            user_id: Math.random() > 0.7 ? `user_${Math.floor(Math.random() * 1000)}` : null,
            request_id: `req_${Math.floor(Math.random() * 10000)}`,
            metadata: {
                response_time: Math.floor(Math.random() * 1000),
                endpoint: `/api/v1/${services[Math.floor(Math.random() * services.length)]}`
            }
        };

        try {
            await fetch('/api/logs', {
                method: 'POST',
                headers: {
                    'Content-Type': 'application/json',
                },
                body: JSON.stringify(logData)
            });
        } catch (error) {
            console.error('Failed to add demo log:', error);
        }

        // Add small delay to simulate real-time logs
        await new Promise(resolve => setTimeout(resolve, 200));
    }
    
    console.log('Demo logs generated!');
};
