using System.ComponentModel;

namespace SignikWindowsApp.Models
{
    public enum DeviceType
    {
        Windows,
        Android
    }

    public enum ConnectionStatus
    {
        Pending,
        Connected,
        Disconnected,
        Rejected
    }

    public class Device : INotifyPropertyChanged
    {
        private bool _isOnline;
        private DateTime _lastHeartbeat;

        public string Id { get; set; } = string.Empty;
        public string Name { get; set; } = string.Empty;
        public DeviceType DeviceType { get; set; }
        public string IpAddress { get; set; } = string.Empty;
        
        public DateTime LastHeartbeat
        {
            get => _lastHeartbeat;
            set
            {
                _lastHeartbeat = value;
                OnPropertyChanged(nameof(LastHeartbeat));
                OnPropertyChanged(nameof(LastSeenText));
            }
        }

        public bool IsOnline
        {
            get => _isOnline;
            set
            {
                _isOnline = value;
                OnPropertyChanged(nameof(IsOnline));
                OnPropertyChanged(nameof(StatusText));
                OnPropertyChanged(nameof(StatusColor));
            }
        }

        // UI Properties
        public string StatusText => IsOnline ? "Online" : "Offline";
        public Color StatusColor => IsOnline ? Color.Green : Color.Red;
        public string LastSeenText => LastHeartbeat == default ? "Never" : 
            (DateTime.Now - LastHeartbeat).TotalMinutes < 1 ? "Just now" : 
            $"{(int)(DateTime.Now - LastHeartbeat).TotalMinutes}m ago";

        public event PropertyChangedEventHandler? PropertyChanged;

        protected virtual void OnPropertyChanged(string propertyName)
        {
            PropertyChanged?.Invoke(this, new PropertyChangedEventArgs(propertyName));
        }
    }

    public class DeviceConnection : INotifyPropertyChanged
    {
        private ConnectionStatus _status;
        private DateTime _updatedAt;

        public string Id { get; set; } = string.Empty;
        public string WindowsDeviceId { get; set; } = string.Empty;
        public string AndroidDeviceId { get; set; } = string.Empty;
        
        public ConnectionStatus Status
        {
            get => _status;
            set
            {
                _status = value;
                OnPropertyChanged(nameof(Status));
                OnPropertyChanged(nameof(StatusText));
                OnPropertyChanged(nameof(StatusColor));
            }
        }

        public DateTime CreatedAt { get; set; }
        
        public DateTime UpdatedAt
        {
            get => _updatedAt;
            set
            {
                _updatedAt = value;
                OnPropertyChanged(nameof(UpdatedAt));
            }
        }

        public string InitiatedBy { get; set; } = string.Empty;

        // UI Properties
        public string StatusText => Status.ToString();
        public Color StatusColor => Status switch
        {
            ConnectionStatus.Connected => Color.Green,
            ConnectionStatus.Pending => Color.Orange,
            ConnectionStatus.Rejected => Color.Red,
            ConnectionStatus.Disconnected => Color.Gray,
            _ => Color.Black
        };

        // Navigation properties
        public Device? WindowsDevice { get; set; }
        public Device? AndroidDevice { get; set; }
        public Device? OtherDevice { get; set; }

        public event PropertyChangedEventHandler? PropertyChanged;

        protected virtual void OnPropertyChanged(string propertyName)
        {
            PropertyChanged?.Invoke(this, new PropertyChangedEventArgs(propertyName));
        }
    }

    public class SignikMessage
    {
        public string Type { get; set; } = string.Empty;
        public string? Name { get; set; }
        public object? Data { get; set; }
        public string? DocId { get; set; }
        public string? DeviceId { get; set; }
        public string? SenderDeviceId { get; set; }
    }
} 