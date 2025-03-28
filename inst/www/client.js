// DuckDBViz Client
class DuckDBVizClient {
  constructor() {
    this.serverUrl = window.duckdbvizConfig?.serverUrl || 'ws://localhost:8765/ws';
    this.httpUrl = window.duckdbvizConfig?.httpUrl || 'http://localhost:8765/query';
    this.connected = false;
    this.socket = null;
    this.requestId = 0;
    this.pendingRequests = new Map();
  }

  // Connect to the server
  async connect() {
    return new Promise((resolve, reject) => {
      try {
        this.socket = new WebSocket(this.serverUrl);
        
        this.socket.onopen = () => {
          console.log('Connected to DuckDBViz server');
          this.connected = true;
          resolve();
        };
        
        this.socket.onclose = () => {
          console.log('Disconnected from DuckDBViz server');
          this.connected = false;
        };
        
        this.socket.onerror = (error) => {
          console.error('WebSocket error:', error);
          reject(error);
        };
        
        this.socket.onmessage = (event) => {
          try {
            const response = JSON.parse(event.data);
            const requestId = response.requestId;
            const pendingRequest = this.pendingRequests.get(requestId);
            
            if (pendingRequest) {
              if (response.error) {
                pendingRequest.reject(new Error(response.error));
              } else {
                pendingRequest.resolve(response.data);
              }
              this.pendingRequests.delete(requestId);
            }
          } catch (error) {
            console.error('Error processing message:', error);
          }
        };
        
        // Set a timeout for the connection
        setTimeout(() => {
          if (!this.connected) {
            reject(new Error('Connection timeout'));
          }
        }, 5000);
      } catch (error) {
        reject(error);
      }
    });
  }

  // Execute a query
  async query(sql) {
    if (!this.connected) {
      throw new Error('Not connected to server');
    }
    
    const requestId = this.requestId++;
    
    return new Promise((resolve, reject) => {
      try {
        // Add to pending requests
        this.pendingRequests.set(requestId, { resolve, reject });
        
        // Send the query
        this.socket.send(JSON.stringify({
          requestId: requestId,
          sql: sql
        }));
        
        // Set a timeout for the query
        setTimeout(() => {
          if (this.pendingRequests.has(requestId)) {
            this.pendingRequests.delete(requestId);
            reject(new Error('Query timed out'));
          }
        }, 10000); // 10 second timeout
      } catch (error) {
        this.pendingRequests.delete(requestId);
        reject(error);
      }
    });
  }

  // Close the connection
  close() {
    if (this.socket) {
      this.socket.close();
      this.socket = null;
      this.connected = false;
    }
  }
}
