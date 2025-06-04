using System;
using System.Drawing;
using System.Windows.Forms;

namespace SignikWindowsApp
{
    public partial class TestForm : Form
    {
        private Button btnTest;
        private Label lblStatus;
        private DataGridView dgvTest;

        public TestForm()
        {
            InitializeComponent();
        }

        private void InitializeComponent()
        {
            this.Text = "Signik Device Manager - Test Window";
            this.Size = new Size(800, 600);
            this.StartPosition = FormStartPosition.CenterScreen;
            this.BackColor = Color.WhiteSmoke;

            // Test Label
            lblStatus = new Label
            {
                Text = "✅ Windows Forms is working! Connection Management UI will appear here.",
                Location = new Point(20, 20),
                Size = new Size(750, 40),
                Font = new Font("Segoe UI", 12, FontStyle.Bold),
                ForeColor = Color.Green,
                BackColor = Color.White,
                TextAlign = ContentAlignment.MiddleCenter
            };

            // Test Button
            btnTest = new Button
            {
                Text = "Test Broker Connection",
                Location = new Point(20, 80),
                Size = new Size(200, 35),
                BackColor = Color.DodgerBlue,
                ForeColor = Color.White,
                FlatStyle = FlatStyle.Flat,
                Font = new Font("Segoe UI", 10, FontStyle.Bold)
            };
            btnTest.Click += BtnTest_Click;

            // Test DataGridView
            dgvTest = new DataGridView
            {
                Location = new Point(20, 130),
                Size = new Size(740, 400),
                BackgroundColor = Color.White,
                BorderStyle = BorderStyle.FixedSingle,
                AllowUserToAddRows = false,
                AllowUserToDeleteRows = false,
                ReadOnly = true,
                SelectionMode = DataGridViewSelectionMode.FullRowSelect,
                MultiSelect = false
            };

            // Add test columns
            dgvTest.Columns.Add("Device", "Device Name");
            dgvTest.Columns.Add("Type", "Type");
            dgvTest.Columns.Add("Status", "Status");
            dgvTest.Columns.Add("IP", "IP Address");

            // Add test data
            dgvTest.Rows.Add("Windows-PC-1", "Windows", "Online", "192.168.1.100");
            dgvTest.Rows.Add("Android-Phone-1", "Android", "Online", "192.168.1.200");
            dgvTest.Rows.Add("Android-Tablet-1", "Android", "Offline", "192.168.1.201");

            // Style the grid
            dgvTest.Columns["Device"].Width = 200;
            dgvTest.Columns["Type"].Width = 100;
            dgvTest.Columns["Status"].Width = 100;
            dgvTest.Columns["IP"].Width = 150;

            this.Controls.AddRange(new Control[] { lblStatus, btnTest, dgvTest });
        }

        private async void BtnTest_Click(object sender, EventArgs e)
        {
            btnTest.Text = "Testing...";
            btnTest.Enabled = false;

            try
            {
                // Test broker connectivity
                using (var client = new System.Net.Http.HttpClient())
                {
                    var response = await client.GetAsync("http://localhost:8000/devices");
                    if (response.IsSuccessStatusCode)
                    {
                        lblStatus.Text = "✅ Successfully connected to Signik Broker! Ready for device management.";
                        lblStatus.ForeColor = Color.Green;

                        // Add more test data to show it's working
                        dgvTest.Rows.Clear();
                        dgvTest.Rows.Add("Your-PC", "Windows", "Connected", "Local");
                        dgvTest.Rows.Add("Test-Android-1", "Android", "Available", "192.168.1.200");
                        dgvTest.Rows.Add("Test-Android-2", "Android", "Available", "192.168.1.201");
                    }
                    else
                    {
                        lblStatus.Text = "❌ Cannot connect to broker. Make sure it's running on port 8000.";
                        lblStatus.ForeColor = Color.Red;
                    }
                }
            }
            catch (Exception ex)
            {
                lblStatus.Text = $"❌ Connection failed: {ex.Message}";
                lblStatus.ForeColor = Color.Red;
            }

            btnTest.Text = "Test Broker Connection";
            btnTest.Enabled = true;
        }
    }
} 