using System.ComponentModel;
using System.Runtime.CompilerServices;
using SignikWindowsApp.Models;
using SignikWindowsApp.Services;

namespace SignikWindowsApp.ViewModels
{
    /// <summary>
    /// View model for the main form
    /// </summary>
    public class MainViewModel : INotifyPropertyChanged
    {
        private readonly ISignikBrokerService _brokerService;
        private readonly System.Timers.Timer _refreshTimer;
        private readonly System.Timers.Timer _heartbeatTimer;

        private string _deviceName = Environment.MachineName;
        private string _statusText = "Not Connected";
        private bool _isConnected = false;
        private Device? _selectedAvailableDevice;
        private DeviceConnection? _selectedConnection;
        private string _deviceTypeFilter = "android";

        public MainViewModel(ISignikBrokerService brokerService)
        {
            _brokerService = brokerService;
            
            // Initialize collections
            AllDevices = new BindingList<Device>();
            AvailableDevices = new BindingList<Device>();
            MyConnections = new BindingList<DeviceConnection>();

            // Setup timers
            _refreshTimer = new System.Timers.Timer(5000); // 5 seconds
            _refreshTimer.Elapsed += async (s, e) => await RefreshAllDataAsync();

            _heartbeatTimer = new System.Timers.Timer(10000); // 10 seconds
            _heartbeatTimer.Elapsed += async (s, e) => await SendHeartbeatAsync();

            // Subscribe to broker events
            _brokerService.ConnectionRequested += OnConnectionRequested;
            _brokerService.ConnectionStatusUpdated += OnConnectionStatusUpdated;
            _brokerService.ConnectionRemoved += OnConnectionRemoved;
        }

        #region Properties

        public string DeviceName
        {
            get => _deviceName;
            set => SetProperty(ref _deviceName, value);
        }

        public string StatusText
        {
            get => _statusText;
            set => SetProperty(ref _statusText, value);
        }

        public bool IsConnected
        {
            get => _isConnected;
            set
            {
                if (SetProperty(ref _isConnected, value))
                {
                    OnPropertyChanged(nameof(CanRegister));
                    OnPropertyChanged(nameof(CanConnect));
                    OnPropertyChanged(nameof(CanDisconnect));
                    OnPropertyChanged(nameof(CanSendPdf));
                }
            }
        }

        public Device? SelectedAvailableDevice
        {
            get => _selectedAvailableDevice;
            set
            {
                if (SetProperty(ref _selectedAvailableDevice, value))
                {
                    OnPropertyChanged(nameof(CanConnect));
                }
            }
        }

        public DeviceConnection? SelectedConnection
        {
            get => _selectedConnection;
            set
            {
                if (SetProperty(ref _selectedConnection, value))
                {
                    OnPropertyChanged(nameof(CanDisconnect));
                    OnPropertyChanged(nameof(CanSendPdf));
                }
            }
        }

        public string DeviceTypeFilter
        {
            get => _deviceTypeFilter;
            set
            {
                if (SetProperty(ref _deviceTypeFilter, value))
                {
                    _ = RefreshAvailableDevicesAsync();
                }
            }
        }

        public BindingList<Device> AllDevices { get; }
        public BindingList<Device> AvailableDevices { get; }
        public BindingList<DeviceConnection> MyConnections { get; }

        public bool CanRegister => !IsConnected && !string.IsNullOrWhiteSpace(DeviceName);
        public bool CanConnect => IsConnected && SelectedAvailableDevice != null;
        public bool CanDisconnect => IsConnected && SelectedConnection != null;
        public bool CanSendPdf => IsConnected && SelectedConnection?.Status == ConnectionStatus.Connected;

        #endregion

        #region Commands

        public async Task RegisterAndConnectAsync()
        {
            if (!CanRegister) return;

            try
            {
                StatusText = "Registering...";
                var ipAddress = NetworkHelper.GetLocalIPAddress();
                
                if (await _brokerService.RegisterDeviceAsync(DeviceName, ipAddress))
                {
                    if (await _brokerService.ConnectWebSocketAsync())
                    {
                        IsConnected = true;
                        StatusText = "Connected";
                        
                        _refreshTimer.Start();
                        _heartbeatTimer.Start();
                        
                        await RefreshAllDataAsync();
                    }
                    else
                    {
                        StatusText = "WebSocket connection failed";
                    }
                }
                else
                {
                    StatusText = "Registration failed";
                }
            }
            catch (Exception ex)
            {
                StatusText = $"Error: {ex.Message}";
            }
        }

        public async Task ConnectToDeviceAsync()
        {
            if (!CanConnect || SelectedAvailableDevice == null) return;

            try
            {
                if (await _brokerService.ConnectToDeviceAsync(SelectedAvailableDevice.Id))
                {
                    await RefreshConnectionsAsync();
                }
            }
            catch (Exception ex)
            {
                StatusText = $"Connection error: {ex.Message}";
            }
        }

        public async Task DisconnectDeviceAsync()
        {
            if (!CanDisconnect || SelectedConnection == null) return;

            try
            {
                await _brokerService.UpdateConnectionStatusAsync(
                    SelectedConnection.Id, 
                    ConnectionStatus.Disconnected
                );
                await RefreshConnectionsAsync();
            }
            catch (Exception ex)
            {
                StatusText = $"Disconnect error: {ex.Message}";
            }
        }

        public async Task RefreshAllDataAsync()
        {
            await Task.WhenAll(
                RefreshAllDevicesAsync(),
                RefreshAvailableDevicesAsync(),
                RefreshConnectionsAsync()
            );
        }

        #endregion

        #region Private Methods

        private async Task RefreshAllDevicesAsync()
        {
            try
            {
                var devices = await _brokerService.GetDevicesAsync();
                UpdateCollection(AllDevices, devices);
            }
            catch (Exception ex)
            {
                Console.WriteLine($"Error refreshing devices: {ex.Message}");
            }
        }

        private async Task RefreshAvailableDevicesAsync()
        {
            try
            {
                var filterType = DeviceTypeFilter == "all" ? null : DeviceTypeFilter;
                var devices = await _brokerService.GetOnlineDevicesAsync(filterType);
                
                // Filter out our own device
                devices = devices.Where(d => d.Id != _brokerService.DeviceId).ToList();
                
                UpdateCollection(AvailableDevices, devices);
            }
            catch (Exception ex)
            {
                Console.WriteLine($"Error refreshing available devices: {ex.Message}");
            }
        }

        private async Task RefreshConnectionsAsync()
        {
            try
            {
                var connections = await _brokerService.GetMyConnectionsAsync();
                UpdateCollection(MyConnections, connections);
            }
            catch (Exception ex)
            {
                Console.WriteLine($"Error refreshing connections: {ex.Message}");
            }
        }

        private async Task SendHeartbeatAsync()
        {
            try
            {
                await _brokerService.SendHeartbeatAsync();
            }
            catch (Exception ex)
            {
                Console.WriteLine($"Heartbeat error: {ex.Message}");
            }
        }

        private void UpdateCollection<T>(BindingList<T> collection, IEnumerable<T> items)
        {
            collection.Clear();
            foreach (var item in items)
            {
                collection.Add(item);
            }
        }

        private void OnConnectionRequested(object? sender, DeviceConnection connection)
        {
            ConnectionRequestReceived?.Invoke(this, connection);
        }

        private async void OnConnectionStatusUpdated(object? sender, DeviceConnection connection)
        {
            await RefreshConnectionsAsync();
        }

        private async void OnConnectionRemoved(object? sender, string connectionId)
        {
            await RefreshConnectionsAsync();
        }

        #endregion

        #region Events

        public event EventHandler<DeviceConnection>? ConnectionRequestReceived;

        public event PropertyChangedEventHandler? PropertyChanged;

        protected virtual void OnPropertyChanged([CallerMemberName] string? propertyName = null)
        {
            PropertyChanged?.Invoke(this, new PropertyChangedEventArgs(propertyName));
        }

        protected bool SetProperty<T>(ref T field, T value, [CallerMemberName] string? propertyName = null)
        {
            if (EqualityComparer<T>.Default.Equals(field, value))
                return false;

            field = value;
            OnPropertyChanged(propertyName);
            return true;
        }

        #endregion

        public void Dispose()
        {
            _refreshTimer?.Stop();
            _refreshTimer?.Dispose();
            _heartbeatTimer?.Stop();
            _heartbeatTimer?.Dispose();
        }
    }
}