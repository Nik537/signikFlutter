using SignikWindowsApp.Models;

namespace SignikWindowsApp.Services
{
    /// <summary>
    /// Interface for Signik broker service operations
    /// </summary>
    public interface ISignikBrokerService : IDisposable
    {
        /// <summary>
        /// Gets the current device ID after registration
        /// </summary>
        string? DeviceId { get; }

        /// <summary>
        /// Gets whether the service is connected to the broker
        /// </summary>
        bool IsConnected { get; }

        /// <summary>
        /// Event raised when a connection request is received
        /// </summary>
        event EventHandler<DeviceConnection>? ConnectionRequested;

        /// <summary>
        /// Event raised when a connection status is updated
        /// </summary>
        event EventHandler<DeviceConnection>? ConnectionStatusUpdated;

        /// <summary>
        /// Event raised when a connection is removed
        /// </summary>
        event EventHandler<string>? ConnectionRemoved;

        /// <summary>
        /// Register device with the broker
        /// </summary>
        Task<bool> RegisterDeviceAsync(string deviceName, string ipAddress);

        /// <summary>
        /// Connect to the broker WebSocket
        /// </summary>
        Task<bool> ConnectWebSocketAsync();

        /// <summary>
        /// Disconnect from the broker WebSocket
        /// </summary>
        Task DisconnectWebSocketAsync();

        /// <summary>
        /// Send heartbeat to maintain online status
        /// </summary>
        Task<bool> SendHeartbeatAsync();

        /// <summary>
        /// Get all registered devices
        /// </summary>
        Task<List<Device>> GetDevicesAsync(string? deviceType = null);

        /// <summary>
        /// Get online devices only
        /// </summary>
        Task<List<Device>> GetOnlineDevicesAsync(string? deviceType = null);

        /// <summary>
        /// Get connections for this device
        /// </summary>
        Task<List<DeviceConnection>> GetMyConnectionsAsync();

        /// <summary>
        /// Request connection to another device
        /// </summary>
        Task<bool> ConnectToDeviceAsync(string targetDeviceId);

        /// <summary>
        /// Update connection status
        /// </summary>
        Task<bool> UpdateConnectionStatusAsync(string connectionId, ConnectionStatus status);

        /// <summary>
        /// Delete a connection
        /// </summary>
        Task<bool> DeleteConnectionAsync(string connectionId);

        /// <summary>
        /// Send a message through WebSocket
        /// </summary>
        Task SendMessageAsync(object message);

        /// <summary>
        /// Send binary data through WebSocket
        /// </summary>
        Task SendBinaryAsync(byte[] data);
    }
}