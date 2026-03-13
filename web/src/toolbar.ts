// ────────────────────────────────────────────
// Formatting Toolbar
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
  toolbarEl = document.querySelector('#doc-toolbar');
  if (!toolbarEl) return;
  renderToolbar();
}

export function setActiveEditor(editor: Editor | null): void {
  activeEditor = editor;
  refreshActiveStates();
}

export function updateToolbarState(element: ElementInfo | null): void {
  currentElement = element;
  if (!toolbarEl) return;

  const btnParam = toolbarEl.querySelector('[data-action="paramref"]') as HTMLButtonElement | null;
  const btnTParam = toolbarEl.querySelector('[data-action="typeparamref"]') as HTMLButtonElement | null;

  const hasParams = (element?.params?.length ?? 0) > 0;
  const hasGenericParams = (element?.genericParams?.length ?? 0) > 0;
  const isLoaded = element !== null;

  if (btnParam) btnParam.disabled = !isLoaded || !hasParams;
  if (btnTParam) btnTParam.style.display = hasGenericParams ? '' : 'none';

  toolbarEl.querySelectorAll<HTMLButtonElement>('.toolbar-btn:not([data-action="help"])').forEach(btn => {
    if (btn.dataset.action === 'paramref') {
      btn.disabled = !isLoaded || !hasParams;
    } else {
      btn.disabled = !isLoaded;
    }
  });
}

// ── Rendering ──

interface ToolbarButton {
  action: string;
  label: string;
  title: string;
  icon?: boolean;
}

function renderToolbar(): void {
  if (!toolbarEl) return;

  const formatGroup: ToolbarButton[] = [
    { action: 'bold', label: 'B', title: 'Bold (Ctrl+B)', icon: true },
    { action: 'italic', label: 'I', title: 'Italic (Ctrl+I)', icon: true },
  ];

  const tagGroup: ToolbarButton[] = [
    { action: 'code', label: 'C', title: '<c> Inline Code (Ctrl+E)', icon: true },
    { action: 'see', label: 'See', title: '<see cref> Type/Member Reference' },
    { action: 'paramref', label: 'Param', title: '<paramref> Parameter Reference' },
    { action: 'typeparamref', label: 'TParam', title: '<typeparamref> Generic Type Reference' },
  ];

  const fmtDiv = createButtonGroup(formatGroup);
  const sep = document.createElement('div');
  sep.className = 'toolbar-sep';
  const tagDiv = createButtonGroup(tagGroup);

  const helpBtn = document.createElement('button');
  helpBtn.className = 'toolbar-btn toolbar-btn-help';
  helpBtn.dataset.action = 'help';
  helpBtn.textContent = '?';
  helpBtn.title = 'XML Doc Tag Reference';
  helpBtn.addEventListener('click', () => showHelpModal());

  toolbarEl.innerHTML = '';
  toolbarEl.appendChild(fmtDiv);
  toolbarEl.appendChild(sep);
  toolbarEl.appendChild(tagDiv);
  toolbarEl.appendChild(helpBtn);
}

function createButtonGroup(buttons: ToolbarButton[]): HTMLDivElement {
  const group = document.createElement('div');
  group.className = 'toolbar-group';

  buttons.forEach(({ action, label, title, icon }) => {
    const btn = document.createElement('button');
    btn.className = 'toolbar-btn' + (icon ? ' toolbar-btn-icon' : '');
    btn.dataset.action = action;
    btn.textContent = label;
    btn.title = title;
    btn.disabled = true;
    btn.addEventListener('click', () => handleAction(action, btn));
    group.appendChild(btn);
  });

  return group;
}

// ── Active State ──

function refreshActiveStates(): void {
  if (!toolbarEl || !activeEditor) return;

  const states: Record<string, boolean> = {
    bold: activeEditor.isActive('bold'),
    italic: activeEditor.isActive('italic'),
    code: activeEditor.isActive('codeInline'),
  };

  toolbarEl.querySelectorAll<HTMLButtonElement>('.toolbar-btn').forEach(btn => {
    const action = btn.dataset.action;
    if (action && action in states) {
      btn.classList.toggle('is-active', states[action]);
    }
  });
}

// ── Actions ──

function handleAction(action: string, btn: HTMLElement): void {
  if (!activeEditor) return;

  switch (action) {
    case 'bold':
      activeEditor.chain().focus().toggleBold().run();
      break;
    case 'italic':
      activeEditor.chain().focus().toggleItalic().run();
      break;
    case 'code':
      activeEditor.chain().focus().toggleMark('codeInline').run();
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
  }

  setTimeout(refreshActiveStates, 0);
}

function showSeePopover(anchor: HTMLElement): void {
  const content = document.createElement('div');
  content.className = 'popover-form';
  content.innerHTML = `
    <label class="popover-label">cref (reference target)</label>
    <input class="popover-input" type="text" placeholder="e.g. TMyClass.DoWork" />
    <button class="popover-submit">Insert</button>
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
