using SignikWindowsApp.Models;
using SignikWindowsApp.Services;
using SignikWindowsApp.ViewModels;
using SignikWindowsApp.Views;
using System.ComponentModel;

namespace SignikWindowsApp
{
    /// <summary>
    /// Refactored main form using MVVM pattern
    /// </summary>
    public partial class MainFormRefactored : Form
    {
        private readonly MainViewModel _viewModel;
        private readonly ISignikBrokerService _brokerService;

        // UI Controls
        private DataGridView dgvAllDevices;
        private DataGridView dgvAvailableDevices;
        private DataGridView dgvMyConnections;
        private TextBox txtDeviceName;
        private Button btnRegister;
        private Button btnRefresh;
        private Button btnConnect;
        private Button btnDisconnect;
        private Button btnSendPDF;
        private ComboBox cmbDeviceFilter;
        private Label lblStatus;
        private StatusStrip statusStrip;
        private ToolStripStatusLabel tsslStatus;
        private ToolStripStatusLabel tsslDeviceId;

        public MainFormRefactored()
        {
            _brokerService = new SignikBrokerService();
            _viewModel = new MainViewModel(_brokerService);
            
            InitializeComponent();
            SetupDataBindings();
            SetupEventHandlers();
        }

        private void InitializeComponent()
        {
            Text = "Signik Device Manager";
            Size = new Size(1200, 800);
            StartPosition = FormStartPosition.CenterScreen;
            BackColor = SystemColors.Control;

            // Create main layout
            var mainPanel = new TableLayoutPanel
            {
                Dock = DockStyle.Fill,
                ColumnCount = 1,
                RowCount = 4,
                Padding = new Padding(10)
            };
            mainPanel.RowStyles.Add(new RowStyle(SizeType.Absolute, 80)); // Header
            mainPanel.RowStyles.Add(new RowStyle(SizeType.Percent, 40));  // Top grids
            mainPanel.RowStyles.Add(new RowStyle(SizeType.Percent, 40));  // Connections
            mainPanel.RowStyles.Add(new RowStyle(SizeType.Absolute, 25)); // Status

            // Header Panel
            var headerPanel = CreateHeaderPanel();
            mainPanel.Controls.Add(headerPanel, 0, 0);

            // Top Grids Panel
            var topGridsPanel = CreateTopGridsPanel();
            mainPanel.Controls.Add(topGridsPanel, 0, 1);

            // Connections Panel
            var connectionsPanel = CreateConnectionsPanel();
            mainPanel.Controls.Add(connectionsPanel, 0, 2);

            // Status Strip
            statusStrip = CreateStatusStrip();
            mainPanel.Controls.Add(statusStrip, 0, 3);

            Controls.Add(mainPanel);
        }

        private Panel CreateHeaderPanel()
        {
            var panel = new Panel
            {
                Dock = DockStyle.Fill,
                BackColor = Color.White,
                Padding = new Padding(10)
            };

            txtDeviceName = new TextBox
            {
                Location = new Point(10, 25),
                Size = new Size(200, 23),
                Font = new Font("Segoe UI", 10)
            };

            btnRegister = new Button
            {
                Location = new Point(220, 23),
                Size = new Size(120, 30),
                Text = "Register & Connect",
                BackColor = Color.FromArgb(0, 120, 212),
                ForeColor = Color.White,
                FlatStyle = FlatStyle.Flat,
                Font = new Font("Segoe UI", 9, FontStyle.Bold)
            };
            btnRegister.FlatAppearance.BorderSize = 0;

            lblStatus = new Label
            {
                Location = new Point(350, 27),
                Size = new Size(400, 20),
                Font = new Font("Segoe UI", 10),
                ForeColor = Color.FromArgb(192, 0, 0)
            };

            btnRefresh = new Button
            {
                Anchor = AnchorStyles.Top | AnchorStyles.Right,
                Location = new Point(panel.Width - 110, 23),
                Size = new Size(100, 30),
                Text = "Refresh All",
                BackColor = Color.FromArgb(0, 192, 0),
                ForeColor = Color.White,
                FlatStyle = FlatStyle.Flat,
                Font = new Font("Segoe UI", 9, FontStyle.Bold)
            };
            btnRefresh.FlatAppearance.BorderSize = 0;

            panel.Controls.AddRange(new Control[] { txtDeviceName, btnRegister, lblStatus, btnRefresh });
            return panel;
        }

        private TableLayoutPanel CreateTopGridsPanel()
        {
            var panel = new TableLayoutPanel
            {
                Dock = DockStyle.Fill,
                ColumnCount = 2,
                RowCount = 1,
                ColumnStyles = { 
                    new ColumnStyle(SizeType.Percent, 50),
                    new ColumnStyle(SizeType.Percent, 50)
                }
            };

            // All Devices Group
            var allDevicesGroup = CreateGroupBox("All Devices", CreateAllDevicesGrid());
            panel.Controls.Add(allDevicesGroup, 0, 0);

            // Available Devices Group
            var availableDevicesPanel = new Panel { Dock = DockStyle.Fill };
            
            cmbDeviceFilter = new ComboBox
            {
                Location = new Point(6, 20),
                Size = new Size(120, 23),
                DropDownStyle = ComboBoxStyle.DropDownList,
                Items = { "All", "Android", "Windows" }
            };

            btnConnect = new Button
            {
                Anchor = AnchorStyles.Top | AnchorStyles.Right,
                Size = new Size(100, 30),
                Text = "Connect",
                BackColor = Color.FromArgb(255, 152, 0),
                ForeColor = Color.White,
                FlatStyle = FlatStyle.Flat,
                Font = new Font("Segoe UI", 9, FontStyle.Bold)
            };
            btnConnect.FlatAppearance.BorderSize = 0;

            var availableDevicesGroup = CreateGroupBox("Available Devices", availableDevicesPanel);
            availableDevicesPanel.Controls.Add(cmbDeviceFilter);
            availableDevicesPanel.Controls.Add(btnConnect);
            availableDevicesPanel.Controls.Add(CreateAvailableDevicesGrid());
            
            panel.Controls.Add(availableDevicesGroup, 1, 0);

            return panel;
        }

        private Panel CreateConnectionsPanel()
        {
            var panel = new Panel { Dock = DockStyle.Fill };
            
            btnDisconnect = new Button
            {
                Anchor = AnchorStyles.Top | AnchorStyles.Right,
                Size = new Size(100, 30),
                Text = "Disconnect",
                BackColor = Color.FromArgb(244, 67, 54),
                ForeColor = Color.White,
                FlatStyle = FlatStyle.Flat,
                Font = new Font("Segoe UI", 9, FontStyle.Bold)
            };
            btnDisconnect.FlatAppearance.BorderSize = 0;

            btnSendPDF = new Button
            {
                Anchor = AnchorStyles.Top | AnchorStyles.Right,
                Size = new Size(90, 30),
                Text = "Send PDF",
                BackColor = Color.FromArgb(76, 175, 80),
                ForeColor = Color.White,
                FlatStyle = FlatStyle.Flat,
                Font = new Font("Segoe UI", 9, FontStyle.Bold)
            };
            btnSendPDF.FlatAppearance.BorderSize = 0;

            var connectionsGroup = CreateGroupBox("My Device Connections", panel);
            panel.Controls.Add(btnDisconnect);
            panel.Controls.Add(btnSendPDF);
            panel.Controls.Add(CreateConnectionsGrid());

            return connectionsGroup;
        }

        private GroupBox CreateGroupBox(string title, Control content)
        {
            var groupBox = new GroupBox
            {
                Text = title,
                Dock = DockStyle.Fill,
                Font = new Font("Segoe UI", 10, FontStyle.Bold),
                Padding = new Padding(6)
            };

            if (content is DataGridView)
            {
                content.Dock = DockStyle.Fill;
                groupBox.Controls.Add(content);
            }
            else if (content is Panel panel)
            {
                panel.Dock = DockStyle.Fill;
                groupBox.Controls.Add(panel);
            }

            return groupBox;
        }

        private DataGridView CreateAllDevicesGrid()
        {
            dgvAllDevices = CreateStyledDataGridView();
            dgvAllDevices.Columns.AddRange(new[]
            {
                new DataGridViewTextBoxColumn { DataPropertyName = "Name", HeaderText = "Device Name", Width = 150 },
                new DataGridViewTextBoxColumn { DataPropertyName = "DeviceType", HeaderText = "Type", Width = 80 },
                new DataGridViewTextBoxColumn { DataPropertyName = "IpAddress", HeaderText = "IP Address", Width = 120 },
                new DataGridViewTextBoxColumn { DataPropertyName = "StatusText", HeaderText = "Status", Width = 80 },
                new DataGridViewTextBoxColumn { DataPropertyName = "LastSeenText", HeaderText = "Last Seen", Width = 100 }
            });
            return dgvAllDevices;
        }

        private DataGridView CreateAvailableDevicesGrid()
        {
            dgvAvailableDevices = CreateStyledDataGridView();
            dgvAvailableDevices.Location = new Point(6, 50);
            dgvAvailableDevices.Size = new Size(550, 200);
            dgvAvailableDevices.Anchor = AnchorStyles.Top | AnchorStyles.Bottom | AnchorStyles.Left | AnchorStyles.Right;
            
            dgvAvailableDevices.Columns.AddRange(new[]
            {
                new DataGridViewTextBoxColumn { DataPropertyName = "Name", HeaderText = "Device Name", Width = 180 },
                new DataGridViewTextBoxColumn { DataPropertyName = "DeviceType", HeaderText = "Type", Width = 80 },
                new DataGridViewTextBoxColumn { DataPropertyName = "IpAddress", HeaderText = "IP Address", Width = 120 },
                new DataGridViewTextBoxColumn { DataPropertyName = "LastSeenText", HeaderText = "Last Seen", Width = 120 }
            });
            return dgvAvailableDevices;
        }

        private DataGridView CreateConnectionsGrid()
        {
            dgvMyConnections = CreateStyledDataGridView();
            dgvMyConnections.Location = new Point(6, 50);
            dgvMyConnections.Anchor = AnchorStyles.Top | AnchorStyles.Bottom | AnchorStyles.Left | AnchorStyles.Right;
            
            dgvMyConnections.Columns.AddRange(new[]
            {
                new DataGridViewTextBoxColumn { DataPropertyName = "Id", HeaderText = "Connection ID", Width = 250 },
                new DataGridViewTextBoxColumn { HeaderText = "Connected Device", Width = 200 },
                new DataGridViewTextBoxColumn { HeaderText = "Device Type", Width = 100 },
                new DataGridViewTextBoxColumn { HeaderText = "IP Address", Width = 120 },
                new DataGridViewTextBoxColumn { DataPropertyName = "StatusText", HeaderText = "Status", Width = 100 },
                new DataGridViewTextBoxColumn { DataPropertyName = "CreatedAt", HeaderText = "Connected At", Width = 150 }
            });
            
            dgvMyConnections.CellFormatting += DgvMyConnections_CellFormatting;
            return dgvMyConnections;
        }

        private DataGridView CreateStyledDataGridView()
        {
            return new DataGridView
            {
                BackgroundColor = Color.White,
                BorderStyle = BorderStyle.None,
                CellBorderStyle = DataGridViewCellBorderStyle.SingleHorizontal,
                GridColor = Color.FromArgb(224, 224, 224),
                AllowUserToAddRows = false,
                AllowUserToDeleteRows = false,
                AllowUserToResizeRows = false,
                ReadOnly = true,
                SelectionMode = DataGridViewSelectionMode.FullRowSelect,
                MultiSelect = false,
                RowHeadersVisible = false,
                Font = new Font("Segoe UI", 9),
                DefaultCellStyle = new DataGridViewCellStyle
                {
                    SelectionBackColor = Color.FromArgb(0, 120, 212),
                    SelectionForeColor = Color.White
                },
                ColumnHeadersDefaultCellStyle = new DataGridViewCellStyle
                {
                    BackColor = Color.FromArgb(245, 245, 245),
                    Font = new Font("Segoe UI", 9, FontStyle.Bold)
                }
            };
        }

        private StatusStrip CreateStatusStrip()
        {
            statusStrip = new StatusStrip();
            tsslStatus = new ToolStripStatusLabel("Not Connected");
            tsslDeviceId = new ToolStripStatusLabel("");
            statusStrip.Items.AddRange(new ToolStripItem[] { tsslStatus, tsslDeviceId });
            return statusStrip;
        }

        private void SetupDataBindings()
        {
            // Bind data sources
            dgvAllDevices.DataSource = _viewModel.AllDevices;
            dgvAvailableDevices.DataSource = _viewModel.AvailableDevices;
            dgvMyConnections.DataSource = _viewModel.MyConnections;

            // Bind properties
            txtDeviceName.DataBindings.Add("Text", _viewModel, nameof(MainViewModel.DeviceName));
            lblStatus.DataBindings.Add("Text", _viewModel, nameof(MainViewModel.StatusText));
            cmbDeviceFilter.DataBindings.Add("SelectedItem", _viewModel, nameof(MainViewModel.DeviceTypeFilter));
            
            // Bind enabled states
            btnRegister.DataBindings.Add("Enabled", _viewModel, nameof(MainViewModel.CanRegister));
            btnConnect.DataBindings.Add("Enabled", _viewModel, nameof(MainViewModel.CanConnect));
            btnDisconnect.DataBindings.Add("Enabled", _viewModel, nameof(MainViewModel.CanDisconnect));
            btnSendPDF.DataBindings.Add("Enabled", _viewModel, nameof(MainViewModel.CanSendPdf));

            // Set initial values
            cmbDeviceFilter.SelectedIndex = 1; // Android
        }

        private void SetupEventHandlers()
        {
            btnRegister.Click += async (s, e) => await _viewModel.RegisterAndConnectAsync();
            btnRefresh.Click += async (s, e) => await _viewModel.RefreshAllDataAsync();
            btnConnect.Click += async (s, e) => await _viewModel.ConnectToDeviceAsync();
            btnDisconnect.Click += async (s, e) => await _viewModel.DisconnectDeviceAsync();
            btnSendPDF.Click += BtnSendPDF_Click;

            dgvAvailableDevices.SelectionChanged += (s, e) =>
            {
                if (dgvAvailableDevices.SelectedRows.Count > 0)
                    _viewModel.SelectedAvailableDevice = (Device)dgvAvailableDevices.SelectedRows[0].DataBoundItem;
                else
                    _viewModel.SelectedAvailableDevice = null;
            };

            dgvMyConnections.SelectionChanged += (s, e) =>
            {
                if (dgvMyConnections.SelectedRows.Count > 0)
                    _viewModel.SelectedConnection = (DeviceConnection)dgvMyConnections.SelectedRows[0].DataBoundItem;
                else
                    _viewModel.SelectedConnection = null;
            };

            _viewModel.ConnectionRequestReceived += ViewModel_ConnectionRequestReceived;
            _viewModel.PropertyChanged += ViewModel_PropertyChanged;
        }

        private void ViewModel_PropertyChanged(object? sender, PropertyChangedEventArgs e)
        {
            if (e.PropertyName == nameof(MainViewModel.IsConnected))
            {
                if (InvokeRequired)
                {
                    Invoke(() => UpdateConnectionStatus());
                }
                else
                {
                    UpdateConnectionStatus();
                }
            }
        }

        private void UpdateConnectionStatus()
        {
            if (_viewModel.IsConnected)
            {
                tsslStatus.Text = "Connected";
                tsslDeviceId.Text = $"Device ID: {_brokerService.DeviceId}";
                lblStatus.ForeColor = Color.Green;
            }
            else
            {
                tsslStatus.Text = "Not Connected";
                tsslDeviceId.Text = "";
                lblStatus.ForeColor = Color.Red;
            }
        }

        private async void ViewModel_ConnectionRequestReceived(object? sender, DeviceConnection connection)
        {
            if (InvokeRequired)
            {
                Invoke(() => ViewModel_ConnectionRequestReceived(sender, connection));
                return;
            }

            using var dialog = new ConnectionRequestDialog(connection);
            dialog.ShowDialog(this);

            var status = dialog.Accepted ? ConnectionStatus.Connected : ConnectionStatus.Rejected;
            await _brokerService.UpdateConnectionStatusAsync(connection.Id, status);
        }

        private void DgvMyConnections_CellFormatting(object? sender, DataGridViewCellFormattingEventArgs e)
        {
            if (e.RowIndex >= 0 && e.RowIndex < _viewModel.MyConnections.Count)
            {
                var connection = _viewModel.MyConnections[e.RowIndex];
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

                // Color code based on status
                if (e.ColumnIndex == 4) // Status column
                {
                    var row = dgvMyConnections.Rows[e.RowIndex];
                    switch (connection.Status)
                    {
                        case ConnectionStatus.Connected:
                            row.DefaultCellStyle.ForeColor = Color.Green;
                            break;
                        case ConnectionStatus.Pending:
                            row.DefaultCellStyle.ForeColor = Color.Orange;
                            break;
                        case ConnectionStatus.Disconnected:
                        case ConnectionStatus.Rejected:
                            row.DefaultCellStyle.ForeColor = Color.Red;
                            break;
                    }
                }
            }
        }

        private async void BtnSendPDF_Click(object? sender, EventArgs e)
        {
            if (_viewModel.SelectedConnection == null) return;

            using var openFileDialog = new OpenFileDialog
            {
                Filter = "PDF files (*.pdf)|*.pdf",
                Title = "Select PDF to send"
            };

            if (openFileDialog.ShowDialog() == DialogResult.OK)
            {
                try
                {
                    var pdfBytes = await File.ReadAllBytesAsync(openFileDialog.FileName);
                    var fileName = Path.GetFileName(openFileDialog.FileName);
                    
                    // Send PDF through broker
                    await _brokerService.SendMessageAsync(new
                    {
                        type = "sendStart",
                        name = fileName,
                        deviceId = _viewModel.SelectedConnection.OtherDevice?.Id
                    });
                    
                    await _brokerService.SendBinaryAsync(pdfBytes);
                    
                    MessageBox.Show($"PDF sent to {_viewModel.SelectedConnection.OtherDevice?.Name}",
                        "Success", MessageBoxButtons.OK, MessageBoxIcon.Information);
                }
                catch (Exception ex)
                {
                    MessageBox.Show($"Error sending PDF: {ex.Message}",
                        "Error", MessageBoxButtons.OK, MessageBoxIcon.Error);
                }
            }
        }

        protected override void OnFormClosing(FormClosingEventArgs e)
        {
            _viewModel?.Dispose();
            _brokerService?.Dispose();
            base.OnFormClosing(e);
        }
    }
}