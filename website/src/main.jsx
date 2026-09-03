import React from 'react';
import ReactDOM from 'react-dom/client';
import App from './App.jsx';
import './index.css';

class GlobalErrorBoundary extends React.Component {
  constructor(props) {
    super(props);
    this.state = { hasError: false, error: null };
  }

  static getDerivedStateFromError(error) {
    return { hasError: true, error };
  }

  componentDidCatch(error, errorInfo) {
    console.error('GlobalErrorBoundary caught error:', error, errorInfo);
  }

  render() {
    if (this.state.hasError) {
      return (
        <div className="min-h-screen bg-[#09090b] text-white flex flex-col items-center justify-center p-6 text-center">
          <h1 className="text-3xl font-bold mb-4">Utter — Safe Mode Active</h1>
          <p className="text-zinc-400 max-w-md mb-6">
            A component encountered an issue during rendering. Reloading to restore interface.
          </p>
          <button
            onClick={() => window.location.reload()}
            className="px-6 py-2.5 rounded-full bg-white text-black font-semibold hover:bg-zinc-200 transition-colors"
          >
            Reload Utter
          </button>
        </div>
      );
    }
    return this.props.children;
  }
}

ReactDOM.createRoot(document.getElementById('root')).render(
  <React.StrictMode>
    <GlobalErrorBoundary>
      <App />
    </GlobalErrorBoundary>
  </React.StrictMode>
);
