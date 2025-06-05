using System.Net;
using System.Net.NetworkInformation;
using System.Net.Sockets;

namespace SignikWindowsApp
{
    /// <summary>
    /// Helper class for network operations
    /// </summary>
    public static class NetworkHelper
    {
        /// <summary>
        /// Get the local IP address of the machine
        /// </summary>
        public static string GetLocalIPAddress()
        {
            try
            {
                // Get all network interfaces
                var interfaces = NetworkInterface.GetAllNetworkInterfaces()
                    .Where(ni => ni.OperationalStatus == OperationalStatus.Up &&
                                ni.NetworkInterfaceType != NetworkInterfaceType.Loopback);

                foreach (var ni in interfaces)
                {
                    var properties = ni.GetIPProperties();
                    var addresses = properties.UnicastAddresses
                        .Where(addr => addr.Address.AddressFamily == AddressFamily.InterNetwork &&
                                      !IPAddress.IsLoopback(addr.Address));

                    var firstAddress = addresses.FirstOrDefault();
                    if (firstAddress != null)
                    {
                        return firstAddress.Address.ToString();
                    }
                }

                // Fallback method
                var host = Dns.GetHostEntry(Dns.GetHostName());
                var ip = host.AddressList
                    .FirstOrDefault(addr => addr.AddressFamily == AddressFamily.InterNetwork &&
                                          !IPAddress.IsLoopback(addr));
                
                return ip?.ToString() ?? "127.0.0.1";
            }
            catch (Exception ex)
            {
                Console.WriteLine($"Error getting local IP: {ex.Message}");
                return "127.0.0.1";
            }
        }

        /// <summary>
        /// Check if a port is available
        /// </summary>
        public static bool IsPortAvailable(int port)
        {
            try
            {
                var properties = IPGlobalProperties.GetIPGlobalProperties();
                var listeners = properties.GetActiveTcpListeners();
                return !listeners.Any(endpoint => endpoint.Port == port);
            }
            catch
            {
                return false;
            }
        }

        /// <summary>
        /// Test connectivity to a host
        /// </summary>
        public static async Task<bool> TestConnectivityAsync(string host, int port, int timeoutMs = 5000)
        {
            try
            {
                using var client = new TcpClient();
                var connectTask = client.ConnectAsync(host, port);
                var timeoutTask = Task.Delay(timeoutMs);

                var completedTask = await Task.WhenAny(connectTask, timeoutTask);
                
                if (completedTask == connectTask)
                {
                    await connectTask; // Ensure any exceptions are thrown
                    return true;
                }
                
                return false;
            }
            catch
            {
                return false;
            }
        }
    }
}