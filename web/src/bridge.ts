import type { DocModel, ElementInfo, InboundMessage, OutboundMessage } from './types';

/** 지정 ms 동안 추가 호출이 없을 때만 실행 */
function debounce<T extends (...args: any[]) => void>(fn: T, ms: number): T {
  let timer: ReturnType<typeof setTimeout> | null = null;
  return ((...args: any[]) => {
    if (timer) clearTimeout(timer);
    timer = setTimeout(() => fn(...args), ms);
  }) as unknown as T;
}

export type DocChangedCallback = (doc: DocModel) => void;
export type ElementLoadedCallback = (element: ElementInfo, doc: DocModel) => void;

/**
 * Delphi ↔ WebView2 통신 브릿지.
 * - Delphi → WebView: window.bridge.receive(message)
 * - WebView → Delphi: window.chrome.webview.postMessage(json)
 */
export class DelphiBridge {
  private onDocChangedListeners: DocChangedCallback[] = [];
  private onElementLoadedListeners: ElementLoadedCallback[] = [];

  private debouncedSendDoc = debounce((doc: DocModel) => {
    this.sendToHost({ type: 'docUpdated', doc });
  }, 500);

  /** Delphi에서 호출 — 메시지 수신 */
  receive(message: InboundMessage): void {
    switch (message.type) {
      case 'loadDoc':
        this.onElementLoadedListeners.forEach(cb =>
          cb(message.data.element, message.data.doc)
        );
        break;
      case 'elementChanged':
        // 요소만 변경, 문서는 유지 — 헤더 업데이트용
        break;
    }
  }

  /** WebView → Delphi 메시지 전송 */
  sendToHost(message: OutboundMessage): void {
    try {
      // WebView2 환경
      (window as any).chrome?.webview?.postMessage(JSON.stringify(message));
    } catch {
      // 독립 브라우저 디버깅 — 콘솔 출력
      console.log('[Bridge → Host]', message);
    }
  }

  /** 에디터에서 문서가 변경되었을 때 (디바운싱 적용) */
  notifyDocChanged(doc: DocModel): void {
    this.debouncedSendDoc(doc);
    this.onDocChangedListeners.forEach(cb => cb(doc));
  }

  /** 문서 로드 콜백 등록 */
  onElementLoaded(callback: ElementLoadedCallback): void {
    this.onElementLoadedListeners.push(callback);
  }

  /** 문서 변경 콜백 등록 */
  onDocChanged(callback: DocChangedCallback): void {
    this.onDocChangedListeners.push(callback);
  }
}

// 전역 인스턴스
export const bridge = new DelphiBridge();
(window as any).bridge = bridge;
