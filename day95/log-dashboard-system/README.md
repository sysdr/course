# Log Dashboard System

A customizable, real-time log dashboard system built with FastAPI backend and React frontend.

## Features

- **Real-time Log Monitoring**: Live log streaming with WebSocket support
- **Customizable Dashboard**: Drag-and-drop widget system with React Grid Layout
- **Multiple Widget Types**: Charts, tables, and custom components
- **Responsive Design**: Modern UI that works on all devices
- **FastAPI Backend**: High-performance Python backend with async support
- **React Frontend**: Modern React 18 with TypeScript support

## Architecture

- **Backend**: FastAPI + WebSockets + Pydantic
- **Frontend**: React 18 + Vite + TypeScript
- **Real-time**: WebSocket communication for live updates
- **Widgets**: Modular system for different data visualizations

## Quick Start

### Prerequisites

- Python 3.11+
- Node.js 18+
- Git

### Installation

1. **Clone the repository**
   ```bash
   git clone <repository-url>
   cd log-dashboard-system
   ```

2. **Start the system**
   ```bash
   ./start.sh
   ```

3. **Access the dashboard**
   - Frontend: http://localhost:3000
   - Backend API: http://localhost:8000

### Stop the system
```bash
./stop.sh
```

## Development

### Backend Development

```bash
cd backend
source ../venv/bin/activate
pip install -r requirements.txt
python app/main.py
```

### Frontend Development

```bash
cd frontend
npm install
npm run dev
```

### Building for Production

```bash
cd frontend
npm run build
```

## Project Structure

```
log-dashboard-system/
├── backend/                 # FastAPI backend
│   ├── app/
│   │   ├── main.py         # Main application entry point
│   │   ├── models.py       # Pydantic models
│   │   └── websocket.py    # WebSocket handlers
│   └── requirements.txt    # Python dependencies
├── frontend/               # React frontend
│   ├── src/
│   │   ├── components/     # React components
│   │   ├── widgets/        # Dashboard widgets
│   │   └── App.tsx         # Main application
│   ├── package.json        # Node.js dependencies
│   └── vite.config.ts      # Vite configuration
├── start.sh                # Startup script
├── stop.sh                 # Shutdown script
└── README.md               # This file
```

## API Endpoints

- `GET /`: Health check
- `GET /logs`: Get log history
- `WebSocket /ws`: Real-time log streaming
- `POST /widgets`: Create new widget
- `GET /widgets`: Get all widgets
- `PUT /widgets/{id}`: Update widget
- `DELETE /widgets/{id}`: Delete widget

## Widget System

The dashboard supports multiple widget types:

- **Chart Widgets**: Line charts, bar charts, pie charts
- **Table Widgets**: Data tables with sorting and filtering
- **Custom Widgets**: Extensible system for custom components

## Contributing

1. Fork the repository
2. Create a feature branch
3. Make your changes
4. Add tests if applicable
5. Submit a pull request

## License

This project is licensed under the MIT License.

## Support

For issues and questions, please open an issue on GitHub.
