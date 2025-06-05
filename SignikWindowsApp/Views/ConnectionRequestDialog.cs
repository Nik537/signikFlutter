using SignikWindowsApp.Models;

namespace SignikWindowsApp.Views
{
    /// <summary>
    /// Dialog for handling incoming connection requests
    /// </summary>
    public partial class ConnectionRequestDialog : Form
    {
        public bool Accepted { get; private set; }
        
        public ConnectionRequestDialog(DeviceConnection connection)
        {
            InitializeComponent(connection);
        }

        private void InitializeComponent(DeviceConnection connection)
        {
            // Form settings
            Text = "Connection Request";
            Size = new Size(400, 200);
            StartPosition = FormStartPosition.CenterParent;
            FormBorderStyle = FormBorderStyle.FixedDialog;
            MaximizeBox = false;
            MinimizeBox = false;

            // Icon
            var iconPictureBox = new PictureBox
            {
                Location = new Point(20, 20),
                Size = new Size(48, 48),
                SizeMode = PictureBoxSizeMode.CenterImage
            };

            // Message label
            var messageLabel = new Label
            {
                Location = new Point(80, 20),
                Size = new Size(280, 60),
                Text = $"Connection request from:\n\n{connection.OtherDevice?.Name ?? "Unknown Device"}\n" +
                       $"Type: {connection.OtherDevice?.DeviceType ?? "Unknown"}\n" +
                       $"IP: {connection.OtherDevice?.IpAddress ?? "Unknown"}",
                Font = new Font(Font.FontFamily, 10)
            };

            // Buttons panel
            var buttonPanel = new FlowLayoutPanel
            {
                Location = new Point(80, 100),
                Size = new Size(280, 40),
                FlowDirection = FlowDirection.RightToLeft,
                WrapContents = false
            };

            // Accept button
            var acceptButton = new Button
            {
                Text = "Accept",
                Size = new Size(100, 30),
                BackColor = Color.Green,
                ForeColor = Color.White,
                FlatStyle = FlatStyle.Flat,
                DialogResult = DialogResult.OK
            };
            acceptButton.Click += (s, e) => 
            {
                Accepted = true;
                Close();
            };

            // Reject button
            var rejectButton = new Button
            {
                Text = "Reject",
                Size = new Size(100, 30),
                BackColor = Color.Red,
                ForeColor = Color.White,
                FlatStyle = FlatStyle.Flat,
                DialogResult = DialogResult.Cancel,
                Margin = new Padding(10, 0, 0, 0)
            };
            rejectButton.Click += (s, e) =>
            {
                Accepted = false;
                Close();
            };

            // Add controls
            buttonPanel.Controls.Add(acceptButton);
            buttonPanel.Controls.Add(rejectButton);
            
            Controls.Add(iconPictureBox);
            Controls.Add(messageLabel);
            Controls.Add(buttonPanel);

            // Set default buttons
            AcceptButton = acceptButton;
            CancelButton = rejectButton;
        }
    }
}