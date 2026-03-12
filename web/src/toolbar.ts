// ────────────────────────────────────────────
// Toolbar — XML Doc 태그 삽입 툴바
// ────────────────────────────────────────────

import type { Editor } from '@tiptap/core';
import type { ElementInfo } from './types';
import { showPopover, hidePopover } from './popover';
import { showHelpModal } from './helpModal';

let activeEditor: Editor | null = null;
let currentElement: ElementInfo | null = null;
let toolbarEl: HTMLElement | null = null;

// ── Public API ──

export function initToolbar(): void {
  toolbarEl = document.querySelector('#tag-toolbar');
  if (!toolbarEl) return;
  renderToolbar();
}

export function setActiveEditor(editor: Editor | null): void {
  activeEditor = editor;
}

export function updateToolbarState(element: ElementInfo | null): void {
  currentElement = element;
  if (!toolbarEl) return;

  const btnParam = toolbarEl.querySelector('[data-action="paramref"]') as HTMLButtonElement | null;
  const btnTParam = toolbarEl.querySelector('[data-action="typeparamref"]') as HTMLButtonElement | null;

  const hasParams = (element?.params?.length ?? 0) > 0;
  const hasGenericParams = (element?.genericParams?.length ?? 0) > 0;
  const isLoaded = element !== null;

  if (btnParam) {
    btnParam.disabled = !hasParams;
  }

  if (btnTParam) {
    btnTParam.style.display = hasGenericParams ? '' : 'none';
  }

  // 전체 비활성화/활성화
  toolbarEl.querySelectorAll<HTMLButtonElement>('.toolbar-btn:not([data-action="help"])').forEach(btn => {
    if (btn.dataset.action === 'paramref') {
      btn.disabled = !isLoaded || !hasParams;
    } else {
      btn.disabled = !isLoaded;
    }
  });
}

// ── Rendering ──

function renderToolbar(): void {
  if (!toolbarEl) return;

  const buttons: { action: string; label: string; title: string }[] = [
    { action: 'code', label: 'Code', title: '<c> 인라인 코드 (Ctrl+E)' },
    { action: 'see', label: 'See', title: '<see cref> 타입/멤버 참조' },
    { action: 'paramref', label: 'Param', title: '<paramref> 파라미터 참조' },
    { action: 'typeparamref', label: 'TParam', title: '<typeparamref> 제네릭 타입 참조' },
    { action: 'note', label: 'Note\u25be', title: '<note> 주의사항/팁/경고 블록' },
  ];

  const btnGroup = document.createElement('div');
  btnGroup.className = 'toolbar-group';

  buttons.forEach(({ action, label, title }) => {
    const btn = document.createElement('button');
    btn.className = 'toolbar-btn';
    btn.dataset.action = action;
    btn.textContent = label;
    btn.title = title;
    btn.disabled = true;
    btn.addEventListener('click', () => handleAction(action, btn));
    btnGroup.appendChild(btn);
  });

  const helpBtn = document.createElement('button');
  helpBtn.className = 'toolbar-btn toolbar-btn-help';
  helpBtn.dataset.action = 'help';
  helpBtn.textContent = '?';
  helpBtn.title = 'XML Doc 태그 도움말';
  helpBtn.addEventListener('click', () => showHelpModal());

  toolbarEl.innerHTML = '';
  toolbarEl.appendChild(btnGroup);
  toolbarEl.appendChild(helpBtn);
}

// ── Actions ──

function handleAction(action: string, btn: HTMLElement): void {
  if (!activeEditor) return;

  switch (action) {
    case 'code':
      applyCode();
      break;
    case 'see':
      showSeePopover(btn);
      break;
    case 'paramref':
      showParamPopover(btn);
      break;
    case 'typeparamref':
      showTypeParamPopover(btn);
      break;
    case 'note':
      showNotePopover(btn);
      break;
  }
}

function applyCode(): void {
  if (!activeEditor) return;
  activeEditor.chain().focus().toggleMark('codeInline').run();
}

function showSeePopover(anchor: HTMLElement): void {
  const content = document.createElement('div');
  content.className = 'popover-form';
  content.innerHTML = `
    <label class="popover-label">cref (참조 대상)</label>
    <input class="popover-input" type="text" placeholder="예: TMyClass.DoWork" />
    <button class="popover-submit">삽입</button>
  `;

  const input = content.querySelector('input')!;
  const submitBtn = content.querySelector('.popover-submit')!;

  const doInsert = () => {
    const cref = input.value.trim();
    if (!cref || !activeEditor) return;
    applyMark(activeEditor, 'seeRef', { cref }, cref);
    hidePopover();
  };

  submitBtn.addEventListener('click', doInsert);
  input.addEventListener('keydown', (e) => {
    if (e.key === 'Enter') doInsert();
  });

  showPopover(anchor, content);
  setTimeout(() => input.focus(), 0);
}

function showParamPopover(anchor: HTMLElement): void {
  const params = currentElement?.params ?? [];
  if (params.length === 0) return;

  const content = document.createElement('div');
  content.className = 'popover-list';

  params.forEach(p => {
    const item = document.createElement('button');
    item.className = 'popover-list-item';
    item.innerHTML = `<span class="popover-item-name">${p.name}</span><span class="popover-item-type">${p.type ?? ''}</span>`;
    item.addEventListener('click', () => {
      if (!activeEditor) return;
      applyMark(activeEditor, 'paramRef', { name: p.name }, p.name);
      hidePopover();
    });
    content.appendChild(item);
  });

  showPopover(anchor, content);
}

function showTypeParamPopover(anchor: HTMLElement): void {
  const typeParams = currentElement?.genericParams ?? [];
  if (typeParams.length === 0) return;

  const content = document.createElement('div');
  content.className = 'popover-list';

  typeParams.forEach(name => {
    const item = document.createElement('button');
    item.className = 'popover-list-item';
    item.textContent = name;
    item.addEventListener('click', () => {
      if (!activeEditor) return;
      applyMark(activeEditor, 'typeParamRef', { name }, name);
      hidePopover();
    });
    content.appendChild(item);
  });

  showPopover(anchor, content);
}

function showNotePopover(anchor: HTMLElement): void {
  const types = [
    { value: 'note', label: 'Note', desc: '일반 참고사항' },
    { value: 'warning', label: 'Warning', desc: '경고' },
    { value: 'tip', label: 'Tip', desc: '유용한 팁' },
    { value: 'caution', label: 'Caution', desc: '주의사항' },
  ];

  const content = document.createElement('div');
  content.className = 'popover-list';

  types.forEach(t => {
    const item = document.createElement('button');
    item.className = 'popover-list-item';
    item.innerHTML = `<span class="popover-item-name">${t.label}</span><span class="popover-item-type">${t.desc}</span>`;
    item.addEventListener('click', () => {
      if (!activeEditor) return;
      activeEditor
        .chain()
        .focus()
        .insertContent({
          type: 'noteBlock',
          attrs: { noteType: t.value },
          content: [{ type: 'text', text: ' ' }],
        })
        .run();
      hidePopover();
    });
    content.appendChild(item);
  });

  showPopover(anchor, content);
}

// ── Mark 적용 헬퍼 ──

function applyMark(
  editor: Editor,
  markType: string,
  attrs: Record<string, string>,
  fallbackText: string
): void {
  const { from, to } = editor.state.selection;
  const hasSelection = from !== to;

  if (hasSelection) {
    editor.chain().focus().setMark(markType, attrs).run();
  } else {
    editor
      .chain()
      .focus()
      .insertContent({
        type: 'text',
        text: fallbackText,
        marks: [{ type: markType, attrs }],
      })
      .run();
  }
}
