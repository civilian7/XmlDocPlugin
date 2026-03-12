// ────────────────────────────────────────────
// Popover — 재사용 가능한 드롭다운/팝오버
// ────────────────────────────────────────────

let activePopover: HTMLElement | null = null;
let cleanupFn: (() => void) | null = null;

export function showPopover(
  anchor: HTMLElement,
  content: HTMLElement,
  onClose?: () => void
): HTMLElement {
  hidePopover();

  const popover = document.createElement('div');
  popover.className = 'popover';
  popover.appendChild(content);
  document.body.appendChild(popover);

  // 위치 계산
  const anchorRect = anchor.getBoundingClientRect();
  const top = anchorRect.bottom + 4;
  popover.style.top = `${top}px`;

  // 먼저 왼쪽 정렬로 배치 후 오버플로우 확인
  popover.style.left = `${anchorRect.left}px`;

  requestAnimationFrame(() => {
    const popoverRect = popover.getBoundingClientRect();
    if (popoverRect.right > window.innerWidth - 8) {
      popover.style.left = '';
      popover.style.right = '8px';
    }
  });

  activePopover = popover;

  const onClickOutside = (e: MouseEvent) => {
    if (!popover.contains(e.target as Node) && !anchor.contains(e.target as Node)) {
      hidePopover();
    }
  };

  const onKeyDown = (e: KeyboardEvent) => {
    if (e.key === 'Escape') {
      hidePopover();
    }
  };

  setTimeout(() => {
    document.addEventListener('click', onClickOutside);
    document.addEventListener('keydown', onKeyDown);
  }, 0);

  cleanupFn = () => {
    document.removeEventListener('click', onClickOutside);
    document.removeEventListener('keydown', onKeyDown);
    onClose?.();
  };

  return popover;
}

export function hidePopover(): void {
  if (activePopover) {
    activePopover.remove();
    activePopover = null;
  }
  if (cleanupFn) {
    cleanupFn();
    cleanupFn = null;
  }
}
