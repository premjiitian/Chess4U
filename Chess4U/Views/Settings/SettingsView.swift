import SwiftUI

struct SettingsView: View {
    @EnvironmentObject var appState: AppState
    @State private var settings: AppSettings = AppSettings()

    var body: some View {
        Form {
            // UI Mode
            Section {
                VStack(alignment: .leading, spacing: 12) {
                    Label("Interface Mode", systemImage: "rectangle.3.group")
                        .font(.subheadline)
                        .fontWeight(.semibold)
                    ForEach(UIMode.allCases, id: \.self) { mode in
                        Button {
                            settings.uiMode = mode
                            appState.updateSettings(settings)
                        } label: {
                            HStack {
                                Image(systemName: mode.icon)
                                    .foregroundColor(.blue)
                                    .frame(width: 24)
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(mode.rawValue)
                                        .foregroundColor(.primary)
                                        .font(.subheadline)
                                    Text(mode.description)
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                                Spacer()
                                if settings.uiMode == mode {
                                    Image(systemName: "checkmark.circle.fill")
                                        .foregroundColor(.blue)
                                }
                            }
                            .padding(.vertical, 4)
                        }
                    }
                }
            } header: {
                Text("UI Mode")
            }

            // Board
            Section {
                Picker("Board Theme", selection: $settings.boardTheme) {
                    ForEach(BoardTheme.allCases, id: \.self) { theme in
                        Text(theme.rawValue).tag(theme)
                    }
                }
                .onChange(of: settings.boardTheme) { _ in
                    appState.updateSettings(settings)
                }

                Picker("Piece Style", selection: $settings.pieceStyle) {
                    ForEach(PieceStyle.allCases, id: \.self) { style in
                        Text(style.rawValue).tag(style)
                    }
                }
                .onChange(of: settings.pieceStyle) { _ in
                    appState.updateSettings(settings)
                }

                Toggle("Show Coordinates", isOn: $settings.showCoordinates)
                    .onChange(of: settings.showCoordinates) { _ in
                        appState.updateSettings(settings)
                    }

                Toggle("Auto-flip Board", isOn: $settings.autoFlipBoard)
                    .onChange(of: settings.autoFlipBoard) { _ in
                        appState.updateSettings(settings)
                    }
            } header: {
                Text("Board")
            }

            // Hints & Difficulty
            Section {
                Picker("Hint Level", selection: $settings.hintLevel) {
                    ForEach(HintLevel.allCases, id: \.self) { level in
                        Text(level.rawValue).tag(level)
                    }
                }
                .onChange(of: settings.hintLevel) { _ in
                    appState.updateSettings(settings)
                }
            } header: {
                Text("Hints & Difficulty")
            }

            // Audio
            Section {
                Toggle("Audio Coach", isOn: $settings.audioCoachEnabled)
                    .onChange(of: settings.audioCoachEnabled) { _ in
                        appState.updateSettings(settings)
                    }

                Toggle("Sound Effects", isOn: $settings.soundEnabled)
                    .onChange(of: settings.soundEnabled) { _ in
                        appState.updateSettings(settings)
                    }
            } header: {
                Text("Audio")
            }

            // Appearance
            Section {
                Picker("Color Theme", selection: $settings.colorThemeName) {
                    Text("System").tag("default")
                    Text("Light").tag("light")
                    Text("Dark").tag("dark")
                }
                .onChange(of: settings.colorThemeName) { _ in
                    appState.updateSettings(settings)
                }

                Toggle("Animations", isOn: $settings.animationsEnabled)
                    .onChange(of: settings.animationsEnabled) { _ in
                        appState.updateSettings(settings)
                    }
            } header: {
                Text("Appearance")
            }

            // About
            Section {
                HStack {
                    Text("Version")
                    Spacer()
                    Text("1.0.0")
                        .foregroundColor(.secondary)
                }
                HStack {
                    Text("Engine")
                    Spacer()
                    Text("Chess4U Engine v1.0")
                        .foregroundColor(.secondary)
                }
            } header: {
                Text("About")
            }
        }
        .navigationTitle("Settings")
        .onAppear {
            settings = appState.settings
        }
    }
}
