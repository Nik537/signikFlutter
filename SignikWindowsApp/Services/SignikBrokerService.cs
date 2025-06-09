using System.Net.WebSockets;
using System.Text;
using Newtonsoft.Json;
using SignikWindowsApp.Models;
using System.Net.Http;

namespace SignikWindowsApp.Services
{
    public class SignikBrokerService : IDisposable
    {
        private readonly HttpClient _httpClient;
        private ClientWebSocket? _webSocket;
        private CancellationTokenSource? _cancellationTokenSource;
        private string _deviceId = string.Empty;
        private readonly string _brokerUrl;
        
        public event EventHandler<Device>? DeviceConnected;
        public event EventHandler<Device>? DeviceDisconnected;
        public event EventHandler<DeviceConnection>? ConnectionRequested;
        public event EventHandler<DeviceConnection>? ConnectionStatusUpdated;
        public event EventHandler<string>? ConnectionRemoved;
        public event EventHandler<SignikMessage>? MessageReceived;

        public string DeviceId => _deviceId;
        public bool IsConnected => _webSocket?.State == WebSocketState.Open;

        public SignikBrokerService(string brokerUrl = "http://localhost:8000")
        {
            _brokerUrl = brokerUrl;
            _httpClient = new HttpClient();
        }

        public async Task<bool> RegisterDeviceAsync(string deviceName, string ipAddress)
        {
            try
            {
                var request = new
                {
                    device_name = deviceName,
                    device_type = "windows",
                    ip_address = ipAddress
                };

                var json = JsonConvert.SerializeObject(request);
                var content = new StringContent(json, Encoding.UTF8, "application/json");
                
                var response = await _httpClient.PostAsync($"{_brokerUrl}/register_device", content);
                
                if (response.IsSuccessStatusCode)
                {
                    var responseJson = await response.Content.ReadAsStringAsync();
                    var result = JsonConvert.DeserializeAnonymousType(responseJson, new { device_id = "", message = "" });
                    _deviceId = result?.device_id ?? string.Empty;
                    return !string.IsNullOrEmpty(_deviceId);
                }
            }
            catch (Exception ex)
            {
                Console.WriteLine($"Error registering device: {ex.Message}");
            }
            return false;
        }

        public async Task<bool> ConnectWebSocketAsync()
        {
            if (string.IsNullOrEmpty(_deviceId))
                return false;

            try
            {
                _webSocket = new ClientWebSocket();
                _cancellationTokenSource = new CancellationTokenSource();
                
                var wsUrl = _brokerUrl.Replace("http://", "ws://").Replace("https://", "wss://");
                await _webSocket.ConnectAsync(new Uri($"{wsUrl}/ws/{_deviceId}"), _cancellationTokenSource.Token);
                
                _ = Task.Run(ListenForMessages, _cancellationTokenSource.Token);
                
                return true;
            }
            catch (Exception ex)
            {
                Console.WriteLine($"Error connecting WebSocket: {ex.Message}");
                return false;
            }
        }

        private async Task ListenForMessages()
        {
            if (_webSocket == null || _cancellationTokenSource == null) return;

            var buffer = new byte[4096];
            
            try
            {
                while (_webSocket.State == WebSocketState.Open && !_cancellationTokenSource.Token.IsCancellationRequested)
                {
                    var result = await _webSocket.ReceiveAsync(new ArraySegment<byte>(buffer), _cancellationTokenSource.Token);
                    
                    if (result.MessageType == WebSocketMessageType.Text)
                    {
                        var messageJson = Encoding.UTF8.GetString(buffer, 0, result.Count);
                        await HandleMessage(messageJson);
                    }
                }
            }
            catch (OperationCanceledException)
            {
                // Normal shutdown
            }
            catch (Exception ex)
            {
                Console.WriteLine($"Error listening for messages: {ex.Message}");
            }
        }

        private async Task HandleMessage(string messageJson)
        {
            try
            {
                var message = JsonConvert.DeserializeObject<SignikMessage>(messageJson);
                if (message == null) return;

                MessageReceived?.Invoke(this, message);

                switch (message.Type)
                {
                    case "connectionRequest":
                        if (message.Data is Newtonsoft.Json.Linq.JObject connectionData)
                        {
                            var connectionId = connectionData["connection_id"]?.ToString();
                            var fromDevice = connectionData["from_device"]?.ToObject<Device>();
                            
                            if (!string.IsNullOrEmpty(connectionId) && fromDevice != null)
                            {
                                var connection = new DeviceConnection
                                {
                                    Id = connectionId,
                                    Status = ConnectionStatus.Pending,
                                    OtherDevice = fromDevice
                                };
                                ConnectionRequested?.Invoke(this, connection);
                            }
                        }
                        break;

                    case "connectionStatusUpdate":
                        if (message.Data is Newtonsoft.Json.Linq.JObject statusData)
                        {
                            var connectionId = statusData["connection_id"]?.ToString();
                            var status = statusData["status"]?.ToString();
                            
                            if (!string.IsNullOrEmpty(connectionId) && Enum.TryParse<ConnectionStatus>(status, true, out var connectionStatus))
                            {
                                var connection = new DeviceConnection
                                {
                                    Id = connectionId,
                                    Status = connectionStatus
                                };
                                ConnectionStatusUpdated?.Invoke(this, connection);
                            }
                        }
                        break;

                    case "connectionRemoved":
                        if (message.Data is Newtonsoft.Json.Linq.JObject removeData)
                        {
                            var connectionId = removeData["connection_id"]?.ToString();
                            if (!string.IsNullOrEmpty(connectionId))
                            {
                                ConnectionRemoved?.Invoke(this, connectionId);
                            }
                        }
                        break;
                }
            }
            catch (Exception ex)
            {
                Console.WriteLine($"Error handling message: {ex.Message}");
            }
        }

        public async Task<List<Device>> GetDevicesAsync(string? deviceType = null)
        {
            try
            {
                var url = $"{_brokerUrl}/devices";
                if (!string.IsNullOrEmpty(deviceType))
                    url += $"?device_type={deviceType}";

                var response = await _httpClient.GetAsync(url);
                if (response.IsSuccessStatusCode)
                {
                    var json = await response.Content.ReadAsStringAsync();
                    var result = JsonConvert.DeserializeAnonymousType(json, new { devices = new List<Device>() });
                    return result?.devices ?? new List<Device>();
                }
            }
            catch (Exception ex)
            {
                Console.WriteLine($"Error getting devices: {ex.Message}");
            }
            return new List<Device>();
        }

        public async Task<List<Device>> GetOnlineDevicesAsync(string? deviceType = null)
        {
            try
            {
                var url = $"{_brokerUrl}/devices/online";
                if (!string.IsNullOrEmpty(deviceType))
                    url += $"?device_type={deviceType}";

                var response = await _httpClient.GetAsync(url);
                if (response.IsSuccessStatusCode)
                {
                    var json = await response.Content.ReadAsStringAsync();
                    var result = JsonConvert.DeserializeAnonymousType(json, new { devices = new List<Device>() });
                    return result?.devices ?? new List<Device>();
                }
            }
            catch (Exception ex)
            {
                Console.WriteLine($"Error getting online devices: {ex.Message}");
            }
            return new List<Device>();
        }

        public async Task<bool> ConnectToDeviceAsync(string targetDeviceId)
        {
            try
            {
                var request = new { target_device_id = targetDeviceId };
                var json = JsonConvert.SerializeObject(request);
                var content = new StringContent(json, Encoding.UTF8, "application/json");
                
                var response = await _httpClient.PostAsync($"{_brokerUrl}/devices/{_deviceId}/connect", content);
                return response.IsSuccessStatusCode;
            }
            catch (Exception ex)
            {
                Console.WriteLine($"Error connecting to device: {ex.Message}");
                return false;
            }
        }

        public async Task<List<DeviceConnection>> GetMyConnectionsAsync()
        {
            try
            {
                var response = await _httpClient.GetAsync($"{_brokerUrl}/devices/{_deviceId}/connections");
                if (response.IsSuccessStatusCode)
                {
                    var json = await response.Content.ReadAsStringAsync();
                    var result = JsonConvert.DeserializeAnonymousType(json, new { connections = new List<DeviceConnection>() });
                    return result?.connections ?? new List<DeviceConnection>();
                }
            }
            catch (Exception ex)
            {
                Console.WriteLine($"Error getting connections: {ex.Message}");
            }
            return new List<DeviceConnection>();
        }

        public async Task<bool> UpdateConnectionStatusAsync(string connectionId, ConnectionStatus status)
        {
            try
            {
                var request = new { status = status.ToString().ToLower() };
                var json = JsonConvert.SerializeObject(request);
                var content = new StringContent(json, Encoding.UTF8, "application/json");
                
                var response = await _httpClient.PutAsync($"{_brokerUrl}/connections/{connectionId}", content);
                return response.IsSuccessStatusCode;
            }
            catch (Exception ex)
            {
                Console.WriteLine($"Error updating connection status: {ex.Message}");
                return false;
            }
        }

        public async Task<bool> SendHeartbeatAsync()
        {
            try
            {
                var response = await _httpClient.PostAsync($"{_brokerUrl}/heartbeat/{_deviceId}", null);
                return response.IsSuccessStatusCode;
            }
            catch (Exception ex)
            {
                Console.WriteLine($"Error sending heartbeat: {ex.Message}");
                return false;
            }
        }

        public async Task<bool> SendMessageAsync(SignikMessage message)
        {
            if (_webSocket?.State != WebSocketState.Open)
                return false;

            try
            {
                var json = JsonConvert.SerializeObject(message);
                var bytes = Encoding.UTF8.GetBytes(json);
                await _webSocket.SendAsync(new ArraySegment<byte>(bytes), WebSocketMessageType.Text, true, CancellationToken.None);
                return true;
            }
            catch (Exception ex)
            {
                Console.WriteLine($"Error sending message: {ex.Message}");
                return false;
            }
        }

        public void Dispose()
        {
            _cancellationTokenSource?.Cancel();
            _webSocket?.Dispose();
            _httpClient?.Dispose();
            _cancellationTokenSource?.Dispose();
        }
    }
} 