using SignikWindowsApp.Models;
using SignikWindowsApp.Services;
using System.ComponentModel;
using System.Net.NetworkInformation;
using System.Net;

namespace SignikWindowsApp
{
    public partial class MainForm : Form
    {
        private readonly SignikBrokerService _brokerService;
        private readonly BindingList<Device> _allDevices;
        private readonly BindingList<Device> _availableDevices;
        private readonly BindingList<DeviceConnection> _myConnections;
        private readonly System.Windows.Forms.Timer _refreshTimer;
        private readonly System.Windows.Forms.Timer _heartbeatTimer;
        private string _currentDeviceName = string.Empty;

        // UI Controls
        private DataGridView dgvAllDevices;
        private DataGridView dgvAvailableDevices;
        private DataGridView dgvMyConnections;
        private Label lblStatus;
        private Button btnRefresh;
        private Button btnConnect;
        private Button btnDisconnect;
        private Button btnSendPDF;
        private ComboBox cmbDeviceFilter;
        private TextBox txtDeviceName;
        private Button btnRegister;
        private GroupBox gbDeviceInfo;
        private GroupBox gbAllDevices;
        private GroupBox gbAvailableDevices;
        private GroupBox gbConnections;
        private StatusStrip statusStrip;
        private ToolStripStatusLabel tsslStatus;
        private ToolStripStatusLabel tsslDeviceId;

        public MainForm()
        {
            _brokerService = new SignikBrokerService();
            _allDevices = new BindingList<Device>();
            _availableDevices = new BindingList<Device>();
            _myConnections = new BindingList<DeviceConnection>();

            InitializeComponent();
            SetupEventHandlers();

            // Setup timers
            _refreshTimer = new System.Windows.Forms.Timer();
            _refreshTimer.Interval = 5000; // 5 seconds
            _refreshTimer.Tick += RefreshTimer_Tick;

            _heartbeatTimer = new System.Windows.Forms.Timer();
            _heartbeatTimer.Interval = 10000; // 10 seconds
            _heartbeatTimer.Tick += HeartbeatTimer_Tick;

            // Set default device name
            _currentDeviceName = Environment.MachineName;
            txtDeviceName.Text = _currentDeviceName;
        }

        private void InitializeComponent()
        {
            this.Text = "Signik Device Manager";
            this.Size = new Size(1200, 800);
            this.StartPosition = FormStartPosition.CenterScreen;
            this.BackColor = Color.WhiteSmoke;

            // Status Strip
            statusStrip = new StatusStrip();
            tsslStatus = new ToolStripStatusLabel("Not Connected");
            tsslDeviceId = new ToolStripStatusLabel("");
            statusStrip.Items.AddRange(new ToolStripItem[] { tsslStatus, tsslDeviceId });
            this.Controls.Add(statusStrip);

            // Device Info GroupBox
            gbDeviceInfo = new GroupBox
            {
                Text = "Device Registration",
                Location = new Point(10, 10),
                Size = new Size(1160, 80),
                BackColor = Color.White
            };

            txtDeviceName = new TextBox
            {
                Location = new Point(10, 25),
                Size = new Size(200, 23),
                PlaceholderText = "Device Name"
            };

            btnRegister = new Button
            {
                Text = "Register & Connect",
                Location = new Point(220, 23),
                Size = new Size(120, 27),
                BackColor = Color.DodgerBlue,
                ForeColor = Color.White,
                FlatStyle = FlatStyle.Flat
            };

            lblStatus = new Label
            {
                Location = new Point(350, 27),
                Size = new Size(300, 20),
                Text = "Status: Not Connected",
                ForeColor = Color.Red
            };

            btnRefresh = new Button
            {
                Text = "Refresh All",
                Location = new Point(1050, 23),
                Size = new Size(100, 27),
                BackColor = Color.LimeGreen,
                ForeColor = Color.White,
                FlatStyle = FlatStyle.Flat
            };

            gbDeviceInfo.Controls.AddRange(new Control[] { txtDeviceName, btnRegister, lblStatus, btnRefresh });
            this.Controls.Add(gbDeviceInfo);

            // All Devices GroupBox
            gbAllDevices = new GroupBox
            {
                Text = "All Devices",
                Location = new Point(10, 100),
                Size = new Size(570, 300),
                BackColor = Color.White
            };

            dgvAllDevices = new DataGridView
            {
                Location = new Point(10, 25),
                Size = new Size(550, 265),
                BackgroundColor = Color.White,
                BorderStyle = BorderStyle.None,
                AllowUserToAddRows = false,
                AllowUserToDeleteRows = false,
                ReadOnly = true,
                SelectionMode = DataGridViewSelectionMode.FullRowSelect,
                MultiSelect = false
            };
            dgvAllDevices.DataSource = _allDevices;
            SetupAllDevicesGrid();

            gbAllDevices.Controls.Add(dgvAllDevices);
            this.Controls.Add(gbAllDevices);

            // Available Devices GroupBox
            gbAvailableDevices = new GroupBox
            {
                Text = "Available Devices for Connection",
                Location = new Point(590, 100),
                Size = new Size(570, 300),
                BackColor = Color.White
            };

            cmbDeviceFilter = new ComboBox
            {
                Location = new Point(10, 25),
                Size = new Size(120, 23),
                DropDownStyle = ComboBoxStyle.DropDownList
            };
            cmbDeviceFilter.Items.AddRange(new[] { "All", "Android", "Windows" });
            cmbDeviceFilter.SelectedIndex = 1; // Default to Android

            btnConnect = new Button
            {
                Text = "Connect",
                Location = new Point(460, 23),
                Size = new Size(100, 27),
                BackColor = Color.Orange,
                ForeColor = Color.White,
                FlatStyle = FlatStyle.Flat,
                Enabled = false
            };

            dgvAvailableDevices = new DataGridView
            {
                Location = new Point(10, 55),
                Size = new Size(550, 235),
                BackgroundColor = Color.White,
                BorderStyle = BorderStyle.None,
                AllowUserToAddRows = false,
                AllowUserToDeleteRows = false,
                ReadOnly = true,
                SelectionMode = DataGridViewSelectionMode.FullRowSelect,
                MultiSelect = false
            };
            dgvAvailableDevices.DataSource = _availableDevices;
            SetupAvailableDevicesGrid();

            gbAvailableDevices.Controls.AddRange(new Control[] { cmbDeviceFilter, btnConnect, dgvAvailableDevices });
            this.Controls.Add(gbAvailableDevices);

            // My Connections GroupBox
            gbConnections = new GroupBox
            {
                Text = "My Device Connections",
                Location = new Point(10, 410),
                Size = new Size(1160, 300),
                BackColor = Color.White
            };

            btnDisconnect = new Button
            {
                Text = "Disconnect",
                Location = new Point(950, 25),
                Size = new Size(100, 27),
                BackColor = Color.Crimson,
                ForeColor = Color.White,
                FlatStyle = FlatStyle.Flat,
                Enabled = false
            };

            btnSendPDF = new Button
            {
                Text = "Send PDF",
                Location = new Point(1060, 25),
                Size = new Size(90, 27),
                BackColor = Color.MediumSeaGreen,
                ForeColor = Color.White,
                FlatStyle = FlatStyle.Flat,
                Enabled = false
            };

            dgvMyConnections = new DataGridView
            {
                Location = new Point(10, 55),
                Size = new Size(1140, 235),
                BackgroundColor = Color.White,
                BorderStyle = BorderStyle.None,
                AllowUserToAddRows = false,
                AllowUserToDeleteRows = false,
                ReadOnly = true,
                SelectionMode = DataGridViewSelectionMode.FullRowSelect,
                MultiSelect = false
            };
            dgvMyConnections.DataSource = _myConnections;
            SetupConnectionsGrid();

            gbConnections.Controls.AddRange(new Control[] { btnDisconnect, btnSendPDF, dgvMyConnections });
            this.Controls.Add(gbConnections);
        }

        private void SetupAllDevicesGrid()
        {
            dgvAllDevices.Columns.Clear();
            dgvAllDevices.Columns.Add(new DataGridViewTextBoxColumn
            {
                DataPropertyName = "Name",
                HeaderText = "Device Name",
                Width = 150
            });
            dgvAllDevices.Columns.Add(new DataGridViewTextBoxColumn
            {
                DataPropertyName = "DeviceType",
                HeaderText = "Type",
                Width = 80
            });
            dgvAllDevices.Columns.Add(new DataGridViewTextBoxColumn
            {
                DataPropertyName = "IpAddress",
                HeaderText = "IP Address",
                Width = 120
            });
            dgvAllDevices.Columns.Add(new DataGridViewTextBoxColumn
            {
                DataPropertyName = "StatusText",
                HeaderText = "Status",
                Width = 80
            });
            dgvAllDevices.Columns.Add(new DataGridViewTextBoxColumn
            {
                DataPropertyName = "LastSeenText",
                HeaderText = "Last Seen",
                Width = 100
            });
        }

        private void SetupAvailableDevicesGrid()
        {
            dgvAvailableDevices.Columns.Clear();
            dgvAvailableDevices.Columns.Add(new DataGridViewTextBoxColumn
            {
                DataPropertyName = "Name",
                HeaderText = "Device Name",
                Width = 180
            });
            dgvAvailableDevices.Columns.Add(new DataGridViewTextBoxColumn
            {
                DataPropertyName = "DeviceType",
                HeaderText = "Type",
                Width = 80
            });
            dgvAvailableDevices.Columns.Add(new DataGridViewTextBoxColumn
            {
                DataPropertyName = "IpAddress",
                HeaderText = "IP Address",
                Width = 120
            });
            dgvAvailableDevices.Columns.Add(new DataGridViewTextBoxColumn
            {
                DataPropertyName = "LastSeenText",
                HeaderText = "Last Seen",
                Width = 120
            });
        }

        private void SetupConnectionsGrid()
        {
            dgvMyConnections.Columns.Clear();
            dgvMyConnections.Columns.Add(new DataGridViewTextBoxColumn
            {
                DataPropertyName = "Id",
                HeaderText = "Connection ID",
                Width = 250
            });
            
            // Custom column for other device name
            var nameColumn = new DataGridViewTextBoxColumn
            {
                HeaderText = "Connected Device",
                Width = 200
            };
            dgvMyConnections.Columns.Add(nameColumn);
            
            // Custom column for other device type
            var typeColumn = new DataGridViewTextBoxColumn
            {
                HeaderText = "Device Type",
                Width = 100
            };
            dgvMyConnections.Columns.Add(typeColumn);
            
            // Custom column for other device IP
            var ipColumn = new DataGridViewTextBoxColumn
            {
                HeaderText = "IP Address",
                Width = 120
            };
            dgvMyConnections.Columns.Add(ipColumn);
            
            dgvMyConnections.Columns.Add(new DataGridViewTextBoxColumn
            {
                DataPropertyName = "StatusText",
                HeaderText = "Status",
                Width = 100
            });
            dgvMyConnections.Columns.Add(new DataGridViewTextBoxColumn
            {
                DataPropertyName = "CreatedAt",
                HeaderText = "Connected At",
                Width = 150
            });

            // Handle custom column data
            dgvMyConnections.CellFormatting += DgvMyConnections_CellFormatting;
        }

        private void DgvMyConnections_CellFormatting(object sender, DataGridViewCellFormattingEventArgs e)
        {
            if (e.RowIndex >= 0 && e.RowIndex < _myConnections.Count)
            {
                var connection = _myConnections[e.RowIndex];
                var otherDevice = connection.OtherDevice;

                switch (e.ColumnIndex)
                {
                    case 1: // Connected Device
                        e.Value = otherDevice?.Name ?? "Unknown";
                        break;
                    case 2: // Device Type
                        e.Value = otherDevice?.DeviceType.ToString() ?? "Unknown";
                        break;
                    case 3: // IP Address
                        e.Value = otherDevice?.IpAddress ?? "Unknown";
                        break;
                }
            }
        }

        private void SetupEventHandlers()
        {
            btnRegister.Click += BtnRegister_Click;
            btnRefresh.Click += BtnRefresh_Click;
            btnConnect.Click += BtnConnect_Click;
            btnDisconnect.Click += BtnDisconnect_Click;
            btnSendPDF.Click += BtnSendPDF_Click;
            cmbDeviceFilter.SelectedIndexChanged += CmbDeviceFilter_SelectedIndexChanged;
            
            dgvAvailableDevices.SelectionChanged += DgvAvailableDevices_SelectionChanged;
            dgvMyConnections.SelectionChanged += DgvMyConnections_SelectionChanged;

            // Broker service events
            _brokerService.ConnectionRequested += BrokerService_ConnectionRequested;
            _brokerService.ConnectionStatusUpdated += BrokerService_ConnectionStatusUpdated;
            _brokerService.ConnectionRemoved += BrokerService_ConnectionRemoved;
        }

        private async void BtnRegister_Click(object sender, EventArgs e)
        {
            if (string.IsNullOrWhiteSpace(txtDeviceName.Text))
            {
                MessageBox.Show("Please enter a device name.", "Error", MessageBoxButtons.OK, MessageBoxIcon.Warning);
                return;
            }

            btnRegister.Enabled = false;
            lblStatus.Text = "Status: Registering...";
            lblStatus.ForeColor = Color.Orange;

            try
            {
                var ipAddress = GetLocalIPAddress();
                var registered = await _brokerService.RegisterDeviceAsync(txtDeviceName.Text, ipAddress);
                
                if (registered)
                {
                    var connected = await _brokerService.ConnectWebSocketAsync();
                    
                    if (connected)
                    {
                        lblStatus.Text = "Status: Connected";
                        lblStatus.ForeColor = Color.Green;
                        tsslStatus.Text = "Connected";
                        tsslDeviceId.Text = $"Device ID: {_brokerService.DeviceId}";
                        
                        _refreshTimer.Start();
                        _heartbeatTimer.Start();
                        
                        await RefreshAllData();
                    }
                    else
                    {
                        lblStatus.Text = "Status: WebSocket Failed";
                        lblStatus.ForeColor = Color.Red;
                    }
                }
                else
                {
                    lblStatus.Text = "Status: Registration Failed";
                    lblStatus.ForeColor = Color.Red;
                }
            }
            catch (Exception ex)
            {
                MessageBox.Show($"Error: {ex.Message}", "Registration Error", MessageBoxButtons.OK, MessageBoxIcon.Error);
                lblStatus.Text = "Status: Error";
                lblStatus.ForeColor = Color.Red;
            }
            finally
            {
                btnRegister.Enabled = true;
            }
        }

        private async void BtnRefresh_Click(object sender, EventArgs e)
        {
            await RefreshAllData();
        }

        private async void BtnConnect_Click(object sender, EventArgs e)
        {
            if (dgvAvailableDevices.SelectedRows.Count == 0) return;

            var selectedDevice = (Device)dgvAvailableDevices.SelectedRows[0].DataBoundItem;
            
            btnConnect.Enabled = false;
            
            try
            {
                var success = await _brokerService.ConnectToDeviceAsync(selectedDevice.Id);
                
                if (success)
                {
                    MessageBox.Show($"Connection request sent to {selectedDevice.Name}", "Success", 
                        MessageBoxButtons.OK, MessageBoxIcon.Information);
                    await RefreshConnections();
                }
                else
                {
                    MessageBox.Show("Failed to send connection request", "Error", 
                        MessageBoxButtons.OK, MessageBoxIcon.Error);
                }
            }
            catch (Exception ex)
            {
                MessageBox.Show($"Error: {ex.Message}", "Connection Error", MessageBoxButtons.OK, MessageBoxIcon.Error);
            }
            finally
            {
                btnConnect.Enabled = dgvAvailableDevices.SelectedRows.Count > 0;
            }
        }

        private async void BtnDisconnect_Click(object sender, EventArgs e)
        {
            if (dgvMyConnections.SelectedRows.Count == 0) return;

            var selectedConnection = (DeviceConnection)dgvMyConnections.SelectedRows[0].DataBoundItem;
            
            var result = MessageBox.Show($"Disconnect from {selectedConnection.OtherDevice?.Name}?", 
                "Confirm Disconnect", MessageBoxButtons.YesNo, MessageBoxIcon.Question);
                
            if (result == DialogResult.Yes)
            {
                try
                {
                    await _brokerService.UpdateConnectionStatusAsync(selectedConnection.Id, ConnectionStatus.Disconnected);
                    await RefreshConnections();
                }
                catch (Exception ex)
                {
                    MessageBox.Show($"Error: {ex.Message}", "Disconnect Error", MessageBoxButtons.OK, MessageBoxIcon.Error);
                }
            }
        }

        private async void BtnSendPDF_Click(object sender, EventArgs e)
        {
            if (dgvMyConnections.SelectedRows.Count == 0) return;

            var selectedConnection = (DeviceConnection)dgvMyConnections.SelectedRows[0].DataBoundItem;
            
            if (selectedConnection.Status != ConnectionStatus.Connected)
            {
                MessageBox.Show("Device must be connected to send PDF", "Error", MessageBoxButtons.OK, MessageBoxIcon.Warning);
                return;
            }

            using (var openFileDialog = new OpenFileDialog())
            {
                openFileDialog.Filter = "PDF files (*.pdf)|*.pdf";
                openFileDialog.Title = "Select PDF to send";
                
                if (openFileDialog.ShowDialog() == DialogResult.OK)
                {
                    try
                    {
                        // Here you would implement PDF sending logic
                        MessageBox.Show($"PDF would be sent to {selectedConnection.OtherDevice?.Name}", 
                            "PDF Send", MessageBoxButtons.OK, MessageBoxIcon.Information);
                    }
                    catch (Exception ex)
                    {
                        MessageBox.Show($"Error: {ex.Message}", "PDF Send Error", MessageBoxButtons.OK, MessageBoxIcon.Error);
                    }
                }
            }
        }

        private async void CmbDeviceFilter_SelectedIndexChanged(object sender, EventArgs e)
        {
            await RefreshAvailableDevices();
        }

        private void DgvAvailableDevices_SelectionChanged(object sender, EventArgs e)
        {
            btnConnect.Enabled = dgvAvailableDevices.SelectedRows.Count > 0 && _brokerService.IsConnected;
        }

        private void DgvMyConnections_SelectionChanged(object sender, EventArgs e)
        {
            var hasSelection = dgvMyConnections.SelectedRows.Count > 0;
            btnDisconnect.Enabled = hasSelection;
            
            if (hasSelection)
            {
                var selectedConnection = (DeviceConnection)dgvMyConnections.SelectedRows[0].DataBoundItem;
                btnSendPDF.Enabled = selectedConnection.Status == ConnectionStatus.Connected;
            }
            else
            {
                btnSendPDF.Enabled = false;
            }
        }

        private async void RefreshTimer_Tick(object sender, EventArgs e)
        {
            await RefreshAllData();
        }

        private async void HeartbeatTimer_Tick(object sender, EventArgs e)
        {
            await _brokerService.SendHeartbeatAsync();
        }

        private async void BrokerService_ConnectionRequested(object sender, DeviceConnection e)
        {
            if (InvokeRequired)
            {
                Invoke(new Action(() => BrokerService_ConnectionRequested(sender, e)));
                return;
            }

            var result = MessageBox.Show($"Connection request from {e.OtherDevice?.Name}. Accept?", 
                "Connection Request", MessageBoxButtons.YesNo, MessageBoxIcon.Question);
                
            var status = result == DialogResult.Yes ? ConnectionStatus.Connected : ConnectionStatus.Rejected;
            await _brokerService.UpdateConnectionStatusAsync(e.Id, status);
            await RefreshConnections();
        }

        private async void BrokerService_ConnectionStatusUpdated(object sender, DeviceConnection e)
        {
            if (InvokeRequired)
            {
                Invoke(new Action(() => BrokerService_ConnectionStatusUpdated(sender, e)));
                return;
            }

            await RefreshConnections();
        }

        private async void BrokerService_ConnectionRemoved(object sender, string connectionId)
        {
            if (InvokeRequired)
            {
                Invoke(new Action(() => BrokerService_ConnectionRemoved(sender, connectionId)));
                return;
            }

            await RefreshConnections();
        }

        private async Task RefreshAllData()
        {
            await Task.WhenAll(
                RefreshAllDevices(),
                RefreshAvailableDevices(),
                RefreshConnections()
            );
        }

        private async Task RefreshAllDevices()
        {
            try
            {
                var devices = await _brokerService.GetDevicesAsync();
                
                if (InvokeRequired)
                {
                    Invoke(new Action(() => UpdateDevicesList(_allDevices, devices)));
                }
                else
                {
                    UpdateDevicesList(_allDevices, devices);
                }
            }
            catch (Exception ex)
            {
                Console.WriteLine($"Error refreshing all devices: {ex.Message}");
            }
        }

        private async Task RefreshAvailableDevices()
        {
            try
            {
                string? deviceType = cmbDeviceFilter.SelectedItem?.ToString()?.ToLower();
                if (deviceType == "all") deviceType = null;
                
                var devices = await _brokerService.GetOnlineDevicesAsync(deviceType);
                
                // Filter out our own device
                devices = devices.Where(d => d.Id != _brokerService.DeviceId).ToList();
                
                if (InvokeRequired)
                {
                    Invoke(new Action(() => UpdateDevicesList(_availableDevices, devices)));
                }
                else
                {
                    UpdateDevicesList(_availableDevices, devices);
                }
            }
            catch (Exception ex)
            {
                Console.WriteLine($"Error refreshing available devices: {ex.Message}");
            }
        }

        private async Task RefreshConnections()
        {
            try
            {
                var connections = await _brokerService.GetMyConnectionsAsync();
                
                if (InvokeRequired)
                {
                    Invoke(new Action(() => UpdateConnectionsList(connections)));
                }
                else
                {
                    UpdateConnectionsList(connections);
                }
            }
            catch (Exception ex)
            {
                Console.WriteLine($"Error refreshing connections: {ex.Message}");
            }
        }

        private void UpdateDevicesList(BindingList<Device> list, List<Device> newDevices)
        {
            list.Clear();
            foreach (var device in newDevices)
            {
                list.Add(device);
            }
        }

        private void UpdateConnectionsList(List<DeviceConnection> newConnections)
        {
            _myConnections.Clear();
            foreach (var connection in newConnections)
            {
                _myConnections.Add(connection);
            }
        }

        private string GetLocalIPAddress()
        {
            try
            {
                var host = Dns.GetHostEntry(Dns.GetHostName());
                return host.AddressList
                    .FirstOrDefault(ip => ip.AddressFamily == System.Net.Sockets.AddressFamily.InterNetwork && 
                                         !IPAddress.IsLoopback(ip))?.ToString() ?? "127.0.0.1";
            }
            catch
            {
                return "127.0.0.1";
            }
        }

        protected override void OnFormClosing(FormClosingEventArgs e)
        {
            _refreshTimer?.Stop();
            _heartbeatTimer?.Stop();
            _brokerService?.Dispose();
            base.OnFormClosing(e);
        }
    }
} 