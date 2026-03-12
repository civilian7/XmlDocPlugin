import { Editor } from '@tiptap/core';
import StarterKit from '@tiptap/starter-kit';
import Placeholder from '@tiptap/extension-placeholder';
import { CodeInline } from './nodes/codeInline';
import { SeeRef } from './nodes/seeRef';
import { ParamRef } from './nodes/paramRef';
import { TypeParamRef } from './nodes/typeParamRef';
import { bridge } from './bridge';
import type { DocModel, ElementInfo, ParamDoc } from './types';
import { initToolbar, setActiveEditor, updateToolbarState } from './toolbar';

// ────────────────────────────────────────────
// State
// ────────────────────────────────────────────
let currentElement: ElementInfo | null = null;
let currentDoc: DocModel = { summary: '' };
let summaryEditor: Editor | null = null;
let remarksEditor: Editor | null = null;
let returnsEditor: Editor | null = null;

const sharedExtensions = [
  StarterKit.configure({ code: false }),
  Placeholder.configure({ placeholder: '설명을 입력하세요...' }),
  CodeInline,
  SeeRef,
  ParamRef,
  TypeParamRef,
];

// ────────────────────────────────────────────
// Helpers
// ────────────────────────────────────────────
function $(selector: string): HTMLElement | null {
  return document.querySelector(selector);
}

function collectDoc(): DocModel {
  const doc: DocModel = {
    summary: summaryEditor?.getText({ blockSeparator: '\n' }) ?? '',
  };

  const remarksText = remarksEditor?.getText({ blockSeparator: '\n' }) ?? '';
  if (remarksText) doc.remarks = remarksText;

  const returnsText = returnsEditor?.getText({ blockSeparator: '\n' }) ?? '';
  if (returnsText) doc.returns = returnsText;

  // Params
  const paramRows = document.querySelectorAll('.param-row');
  if (paramRows.length > 0) {
    doc.params = [];
    paramRows.forEach(row => {
      const name = row.querySelector('.param-name')?.textContent ?? '';
      const desc = (row.querySelector('.param-desc') as HTMLElement)?.innerText ?? '';
      doc.params!.push({ name, description: desc });
    });
  }

  // Exceptions
  const exRows = document.querySelectorAll('.exception-row');
  if (exRows.length > 0) {
    doc.exceptions = [];
    exRows.forEach(row => {
      const typeRef = (row.querySelector('.exception-type') as HTMLInputElement)?.value ?? '';
      const desc = (row.querySelector('.exception-desc') as HTMLElement)?.innerText ?? '';
      doc.exceptions!.push({ typeRef, description: desc });
    });
  }

  // Examples
  const exampleRows = document.querySelectorAll('.example-row');
  if (exampleRows.length > 0) {
    doc.examples = [];
    exampleRows.forEach(row => {
      const description = (row.querySelector('.example-desc') as HTMLElement)?.innerText ?? '';
      const code = (row.querySelector('.example-code') as HTMLTextAreaElement)?.value ?? '';
      doc.examples!.push({ description, code });
    });
  }

  // SeeAlso
  const seeRows = document.querySelectorAll('.seealso-row');
  if (seeRows.length > 0) {
    doc.seeAlso = [];
    seeRows.forEach(row => {
      const cref = (row.querySelector('.seealso-cref') as HTMLInputElement)?.value ?? '';
      doc.seeAlso!.push({ cref });
    });
  }

  return doc;
}

function notifyChanged(): void {
  currentDoc = collectDoc();
  bridge.notifyDocChanged(currentDoc);
}

// ────────────────────────────────────────────
// UI Rendering
// ────────────────────────────────────────────
function renderHeader(el: ElementInfo): void {
  const header = $('#element-header')!;
  const kindLabel = el.methodKind ?? el.kind;
  const parentLabel = el.qualifiedParent ? el.qualifiedParent + '.' : '';
  const fileLabel = el.fileName ?? '';
  const lineLabel = el.lineNumber ? ` / ${el.lineNumber}` : '';
  header.innerHTML = `
    <span class="element-kind">${kindLabel}</span>
    <span class="element-name">${parentLabel}${el.name}</span>
    <span class="element-line">${fileLabel}${lineLabel}</span>
  `;
}

function renderParams(params: ParamDoc[], elementParams: ElementInfo['params']): void {
  const container = $('#params-section .section-body')!;
  container.innerHTML = '';

  // 코드 시그니처의 파라미터 목록 기준
  const sigParams = elementParams ?? [];
  if (sigParams.length === 0) {
    $('#params-section')!.classList.add('hidden');
    return;
  }
  $('#params-section')!.classList.remove('hidden');

  sigParams.forEach(sp => {
    const docParam = params.find(p => p.name === sp.name);
    const row = document.createElement('div');
    row.className = 'param-row';
    row.innerHTML = `
      <span class="param-name" title="${sp.type ?? ''}">${sp.name}</span>
      <span class="param-desc" contenteditable="true" data-placeholder="설명...">${docParam?.description ?? ''}</span>
    `;
    row.querySelector('.param-desc')!.addEventListener('input', notifyChanged);
    container.appendChild(row);
  });
}

function renderExceptions(exceptions: DocModel['exceptions']): void {
  const container = $('#exceptions-section .section-body')!;
  container.querySelectorAll('.exception-row').forEach(r => r.remove());

  (exceptions ?? []).forEach(ex => {
    addExceptionRow(container, ex.typeRef, ex.description);
  });
}

function addExceptionRow(
  container: HTMLElement,
  typeRef: string = '',
  description: string = ''
): void {
  const row = document.createElement('div');
  row.className = 'exception-row';
  row.innerHTML = `
    <input class="exception-type" value="${typeRef}" placeholder="예외 타입 (예: EArgumentException)" />
    <span class="exception-desc" contenteditable="true" data-placeholder="설명...">${description}</span>
    <button class="btn-remove" title="삭제">&times;</button>
  `;
  row.querySelector('.exception-type')!.addEventListener('input', notifyChanged);
  row.querySelector('.exception-desc')!.addEventListener('input', notifyChanged);
  row.querySelector('.btn-remove')!.addEventListener('click', () => {
    row.remove();
    notifyChanged();
  });
  const btn = container.querySelector('.btn-add');
  if (btn) {
    container.insertBefore(row, btn);
  } else {
    container.appendChild(row);
  }
}

function renderExamples(examples: DocModel['examples']): void {
  const container = $('#examples-section .section-body')!;
  container.querySelectorAll('.example-row').forEach(r => r.remove());

  (examples ?? []).forEach(ex => {
    addExampleRow(container, ex.description, ex.code);
  });
}

function addExampleRow(
  container: HTMLElement,
  description: string = '',
  code: string = ''
): void {
  const row = document.createElement('div');
  row.className = 'example-row';
  row.innerHTML = `
    <span class="example-desc" contenteditable="true" data-placeholder="설명 (선택)...">${description}</span>
    <textarea class="example-code" placeholder="코드 예시..." rows="3">${code}</textarea>
    <button class="btn-remove" title="삭제">&times;</button>
  `;
  row.querySelector('.example-desc')!.addEventListener('input', notifyChanged);
  row.querySelector('.example-code')!.addEventListener('input', notifyChanged);
  row.querySelector('.btn-remove')!.addEventListener('click', () => {
    row.remove();
    notifyChanged();
  });
  const btn = container.querySelector('.btn-add');
  if (btn) {
    container.insertBefore(row, btn);
  } else {
    container.appendChild(row);
  }
}

function renderSeeAlso(seeAlso: DocModel['seeAlso']): void {
  const container = $('#seealso-section .section-body')!;
  container.querySelectorAll('.seealso-row').forEach(r => r.remove());

  (seeAlso ?? []).forEach(sa => {
    addSeeAlsoRow(container, sa.cref);
  });
}

function addSeeAlsoRow(container: HTMLElement, cref: string = ''): void {
  const row = document.createElement('div');
  row.className = 'seealso-row';
  row.innerHTML = `
    <input class="seealso-cref" value="${cref}" placeholder="참조 (예: TMyClass.DoWork)" />
    <button class="btn-remove" title="삭제">&times;</button>
  `;
  row.querySelector('.seealso-cref')!.addEventListener('input', notifyChanged);
  row.querySelector('.btn-remove')!.addEventListener('click', () => {
    row.remove();
    notifyChanged();
  });
  const btn = container.querySelector('.btn-add');
  if (btn) {
    container.insertBefore(row, btn);
  } else {
    container.appendChild(row);
  }
}

function setupCollapsible(): void {
  document.querySelectorAll('.section-header.collapsible').forEach(header => {
    header.addEventListener('click', () => {
      const section = header.parentElement!;
      section.classList.toggle('collapsed');
    });
  });
}

function setupAddButtons(): void {
  $('#btn-add-exception')?.addEventListener('click', () => {
    const container = $('#exceptions-section .section-body')!;
    addExceptionRow(container);
    $('#exceptions-section')!.classList.remove('collapsed');
    notifyChanged();
  });

  $('#btn-add-example')?.addEventListener('click', () => {
    const container = $('#examples-section .section-body')!;
    addExampleRow(container);
    $('#examples-section')!.classList.remove('collapsed');
    notifyChanged();
  });

  $('#btn-add-seealso')?.addEventListener('click', () => {
    const container = $('#seealso-section .section-body')!;
    addSeeAlsoRow(container);
    $('#seealso-section')!.classList.remove('collapsed');
    notifyChanged();
  });
}

// ────────────────────────────────────────────
// TipTap Editors
// ────────────────────────────────────────────
/** 줄바꿈이 포함된 plain text를 HTML 단락으로 변환 */
function textToHtml(text: string): string {
  if (!text) return '';
  if (!text.includes('\n')) return `<p>${text}</p>`;
  return text
    .split('\n')
    .filter(line => line.trim() !== '')
    .map(line => `<p>${line}</p>`)
    .join('');
}

function createEditor(element: HTMLElement, content: string, placeholder: string): Editor {
  return new Editor({
    element,
    extensions: [
      ...sharedExtensions,
      Placeholder.configure({ placeholder }),
    ],
    content: textToHtml(content),
    onUpdate: () => notifyChanged(),
    onFocus: ({ editor }) => setActiveEditor(editor),
  });
}

function initEditors(doc: DocModel): void {
  // Summary
  summaryEditor?.destroy();
  summaryEditor = createEditor(
    $('#summary-editor')!,
    doc.summary,
    '요약 설명을 입력하세요...'
  );

  // Remarks
  remarksEditor?.destroy();
  remarksEditor = createEditor(
    $('#remarks-editor')!,
    doc.remarks ?? '',
    '추가 설명...'
  );

  // Returns
  returnsEditor?.destroy();
  returnsEditor = createEditor(
    $('#returns-editor')!,
    doc.returns ?? '',
    '반환값 설명...'
  );
}

// ────────────────────────────────────────────
// Load Document
// ────────────────────────────────────────────
function loadDocument(element: ElementInfo, doc: DocModel): void {
  currentElement = element;
  currentDoc = doc;

  renderHeader(element);
  initEditors(doc);
  renderParams(doc.params ?? [], element.params);

  // Returns 섹션 가시성
  const hasReturn = element.kind === 'method' && !!element.returnType;
  $('#returns-section')!.classList.toggle('hidden', !hasReturn);

  renderExamples(doc.examples);
  renderExceptions(doc.exceptions);
  renderSeeAlso(doc.seeAlso);
  updateToolbarState(element);
}

// ────────────────────────────────────────────
// Init
// ────────────────────────────────────────────
export function init(): void {
  initToolbar();
  setupCollapsible();
  setupAddButtons();

  bridge.onElementLoaded((element, doc) => {
    loadDocument(element, doc);
  });

  // 디버깅용: 샘플 데이터 로드
  if (!((window as any).chrome?.webview)) {
    loadDocument(
      {
        kind: 'method',
        name: 'UpdateUser',
        qualifiedParent: 'TUserManager',
        methodKind: 'function',
        params: [
          { name: 'AUserId', type: 'Integer' },
          { name: 'ANewName', type: 'string', isConst: true },
        ],
        returnType: 'Boolean',
        genericParams: ['T'],
      },
      {
        summary: '사용자 정보를 업데이트합니다.',
        params: [
          { name: 'AUserId', description: '대상 사용자 ID' },
          { name: 'ANewName', description: '새로운 이름' },
        ],
        returns: '업데이트 성공 여부',
        examples: [
          { description: '사용자 이름 변경', code: 'LResult := UserMgr.UpdateUser(1, \'홍길동\');' },
        ],
        exceptions: [
          { typeRef: 'EUserNotFoundException', description: '사용자를 찾을 수 없을 때 발생' },
        ],
        seeAlso: [{ cref: 'TUserManager.FindUser' }],
      }
    );
  }
}
