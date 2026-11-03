/** Push notifications (FCM). Abstracted so handlers are testable and the emulator can no-op. */
export interface PushMessage {
  title: string;
  body: string;
  data?: Record<string, string>;
}

export interface Notifier {
  sendToUser(uid: string, msg: PushMessage): Promise<void>;
}

/** Collects messages; used in tests and in the emulator (FCM is not emulated). */
export class RecordingNotifier implements Notifier {
  sent: { uid: string; msg: PushMessage }[] = [];
  async sendToUser(uid: string, msg: PushMessage) {
    this.sent.push({ uid, msg });
  }
}
