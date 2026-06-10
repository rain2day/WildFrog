import SwiftUI

struct NotificationsView: View {
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            VStack(spacing: 24) {
                Spacer()
                Image(systemName: "bell.slash")
                    .font(.system(size: 48, weight: .light))
                    .foregroundStyle(FrogTheme.muted)
                VStack(spacing: 6) {
                    Text("暫無通知")
                        .font(.frogTitle)
                        .foregroundStyle(FrogTheme.forest)
                    Text("即將推出")
                        .font(.frogMicro.weight(.semibold))
                        .foregroundStyle(FrogTheme.orange)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 4)
                        .background(FrogTheme.orangeSoft, in: Capsule())
                    Text("打卡紀念、活動提醒同挑戰通知即將上線")
                        .font(.frogCaption)
                        .foregroundStyle(FrogTheme.muted)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 32)
                }
                Spacer()
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(FrogTheme.warmPaper.ignoresSafeArea())
            .navigationTitle("通知")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("完成") { dismiss() }
                        .font(.frogCaption.weight(.bold))
                        .foregroundStyle(FrogTheme.orange)
                }
            }
        }
    }
}
