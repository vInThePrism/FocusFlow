import SwiftUI
import AppKit

struct SettingsScreen: View {
    @AppStorage(Pref.focusMinutes) private var focusMin = 25
    @AppStorage(Pref.shortBreakMinutes) private var shortMin = 5
    @AppStorage(Pref.longBreakMinutes) private var longMin = 15
    @AppStorage(Pref.autoStart) private var autoStart = true
    @AppStorage(Pref.soundsOn) private var soundsOn = true
    @AppStorage(Pref.soundTheme) private var soundTheme = SoundTheme.calm.rawValue
    @AppStorage(Pref.idlePause) private var idlePause = true
    @AppStorage(Pref.idleMinutes) private var idleMinutes = 5
    @AppStorage(Pref.dailyGoal) private var dailyGoal = 6
    @AppStorage(Pref.dailyStudyMinutes) private var studyMinutes = 360
    @AppStorage(Pref.repeatExtension) private var repeatExt = true
    @AppStorage(Pref.extendMinutes) private var extendMin = 5
    @AppStorage(Pref.menuBarTime) private var menuBarTime = true
    @AppStorage(Pref.miniTimer) private var miniTimer = false
    @State private var activeTile: Phase = .focus

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Settings")
                        .font(.system(size: 28, weight: .bold))
                        .foregroundColor(Palette.ink)
                    Text("Customize your focus experience.")
                        .font(.system(size: 14))
                        .foregroundColor(Palette.inkSoft)
                }
                .padding(.bottom, 8)

                lengthsCard

                SettingRow(title: "Auto-start rules", icon: "play.fill") {
                    ToggleLine(title: "Automatically start next session",
                               subtitle: "Begin the next focus session after a break ends.",
                               isOn: $autoStart)
                }

                SettingRow(title: "Sounds", icon: "speaker.wave.2.fill") {
                    ToggleLine(title: "Play session start/end sounds", isOn: $soundsOn)
                    OptionLine(title: "Sound theme") {
                        Picker("", selection: $soundTheme) {
                            ForEach(SoundTheme.allCases) { t in
                                Text(t.rawValue).tag(t.rawValue)
                            }
                        }
                        .labelsHidden()
                        .pickerStyle(.menu)
                        .frame(width: 130)
                        .disabled(!soundsOn)
                    }
                }

                SettingRow(title: "Idle pause", icon: "desktopcomputer") {
                    ToggleLine(title: "Pause when idle", isOn: $idlePause)
                    OptionLine(title: "Auto-pause if no input is detected for") {
                        Picker("", selection: $idleMinutes) {
                            ForEach([1, 2, 3, 5, 10, 15, 30], id: \.self) { m in
                                Text(m == 1 ? "1 minute" : "\(m) minutes").tag(m)
                            }
                        }
                        .labelsHidden()
                        .pickerStyle(.menu)
                        .frame(width: 130)
                        .disabled(!idlePause)
                    }
                }

                SettingRow(title: "Daily goals", icon: "scope") {
                    OptionLine(title: "Target sessions per day (pomodoros)") {
                        ValueStepper(value: $dailyGoal, range: 1...24, width: 100)
                    }
                    OptionLine(title: "Study time per day (split across Plan tasks)") {
                        ValueStepper(value: $studyMinutes, range: 30...960, step: 30, width: 100, format: { Fmt.hm($0 * 60) })
                    }
                }

                SettingRow(title: "Extended time", icon: "clock") {
                    ToggleLine(title: "Repeat +\(extendMin) minute extension",
                               subtitle: "Keep adding \(extendMin) minutes with one click.",
                               isOn: $repeatExt)
                    OptionLine(title: "Minutes per extension") {
                        Picker("", selection: $extendMin) {
                            ForEach([1, 3, 5, 10, 15, 20, 30], id: \.self) { m in
                                Text("+\(m) min").tag(m)
                            }
                        }
                        .labelsHidden()
                        .pickerStyle(.menu)
                        .frame(width: 130)
                    }
                }

                SettingRow(title: "Menu bar", icon: "menubar.rectangle") {
                    ToggleLine(title: "Show countdown in the menu bar", isOn: $menuBarTime)
                    ToggleLine(title: "Floating mini timer",
                               subtitle: "A small always-on-top timer you can drag anywhere.",
                               isOn: $miniTimer)
                }

                SettingRow(title: "Data & backup", icon: "externaldrive.fill") {
                    DataPanel()
                }
            }
            .padding(EdgeInsets(top: 34, leading: 30, bottom: 30, trailing: 30))
            .frame(maxWidth: 860, alignment: .leading)
        }
        .onChange(of: soundTheme) { value in
            if soundsOn, let t = SoundTheme(rawValue: value) {
                NSSound(named: NSSound.Name(t.endSound))?.play()
            }
        }
    }

    private var lengthsCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Session lengths")
                .font(.system(size: 15, weight: .semibold))
                .foregroundColor(Palette.ink)
            HStack(spacing: 12) {
                LengthTile(phase: .focus, value: $focusMin, range: 1...180, active: $activeTile)
                LengthTile(phase: .shortBreak, value: $shortMin, range: 1...60, active: $activeTile)
                LengthTile(phase: .longBreak, value: $longMin, range: 1...90, active: $activeTile)
            }
        }
        .padding(18)
        .background(RoundedRectangle(cornerRadius: 16, style: .continuous).fill(Palette.card))
        .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous).strokeBorder(Palette.stroke))
    }
}

struct LengthTile: View {
    let phase: Phase
    @Binding var value: Int
    let range: ClosedRange<Int>
    @Binding var active: Phase

    var body: some View {
        let on = active == phase
        HStack(spacing: 14) {
            Image(systemName: phase.icon)
                .font(.system(size: 24))
                .foregroundColor(phase == .shortBreak ? Palette.inkSoft : Palette.red)
                .frame(width: 30)
            VStack(alignment: .leading, spacing: 4) {
                Text(phase.lowerTitle)
                    .font(.system(size: 12))
                    .foregroundColor(Palette.inkSoft)
                ValueStepper(value: $value, range: range, suffix: " min", width: 120) {
                    active = phase
                }
            }
            Spacer(minLength: 0)
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(RoundedRectangle(cornerRadius: 14, style: .continuous).fill(on ? Color.white : Palette.blushLight.opacity(0.6)))
        .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous).strokeBorder(on ? Palette.red : Palette.stroke, lineWidth: on ? 2 : 1))
        .contentShape(Rectangle())
        .onTapGesture { active = phase }
    }
}

struct SettingRow<Content: View>: View {
    let title: String
    let icon: String
    @ViewBuilder var content: () -> Content

    var body: some View {
        HStack(alignment: .top, spacing: 16) {
            Text(title)
                .font(.system(size: 15, weight: .semibold))
                .foregroundColor(Palette.ink)
                .frame(width: 130, alignment: .leading)
                .padding(.top, 7)
            IconBadge(systemName: icon, size: 34)
            VStack(alignment: .leading, spacing: 12) {
                content()
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.top, 2)
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 16)
        .background(RoundedRectangle(cornerRadius: 16, style: .continuous).fill(Palette.card))
        .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous).strokeBorder(Palette.stroke))
    }
}

struct ToggleLine: View {
    let title: String
    var subtitle: String? = nil
    @Binding var isOn: Bool

    var body: some View {
        HStack(alignment: .center) {
            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(.system(size: 14))
                    .foregroundColor(Palette.ink)
                if let s = subtitle {
                    Text(s)
                        .font(.system(size: 12))
                        .foregroundColor(Palette.muted)
                }
            }
            Spacer()
            Toggle("", isOn: $isOn)
                .toggleStyle(PillToggleStyle())
                .labelsHidden()
        }
    }
}

struct OptionLine<Content: View>: View {
    let title: String
    @ViewBuilder var content: () -> Content

    var body: some View {
        HStack {
            Text(title)
                .font(.system(size: 13))
                .foregroundColor(Palette.inkSoft)
            Spacer()
            content()
        }
    }
}

struct DataPanel: View {
    @EnvironmentObject var store: Store

    private var status: String {
        var parts = ["\(store.records.count) sessions", "\(store.backupCount) daily backups (30 days kept)"]
        if let saved = store.lastSaved {
            parts.append("last saved \(Fmt.time.string(from: saved))")
        }
        return parts.joined(separator: " · ")
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Sessions are saved only on this Mac — nothing is uploaded. The running session is saved every 30 seconds.")
                .font(.system(size: 14))
                .foregroundColor(Palette.ink)
                .fixedSize(horizontal: false, vertical: true)
            Text(store.fileURL.path)
                .font(.system(size: 11, design: .monospaced))
                .foregroundColor(Palette.inkSoft)
                .textSelection(.enabled)
                .lineLimit(2)
            Text(status)
                .font(.system(size: 12))
                .foregroundColor(Palette.muted)
            if let problem = store.problem {
                Text(problem)
                    .font(.system(size: 12))
                    .foregroundColor(Palette.red)
                    .fixedSize(horizontal: false, vertical: true)
            }
            HStack(spacing: 8) {
                Button("Show in Finder") { DataActions.reveal(store) }
                Button("Export JSON…") { DataActions.exportJSON(store) }
                Button("Export CSV…") { DataActions.exportCSV(store) }
                Button("Import / Restore…") { DataActions.importFile(store) }
            }
            .buttonStyle(SmallButtonStyle())
            HStack(spacing: 8) {
                Button("Change Location…") { DataActions.chooseFolder(store) }
                if !store.usesDefaultFolder {
                    Button("Use Default Location") { store.moveData(to: Store.defaultFolder) }
                }
            }
            .buttonStyle(SmallButtonStyle())
            Text("Tip: choose a folder in iCloud Drive to keep an extra copy off this Mac.")
                .font(.system(size: 11))
                .foregroundColor(Palette.muted)
        }
    }
}
