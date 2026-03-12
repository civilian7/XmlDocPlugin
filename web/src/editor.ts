import { Editor } from '@tiptap/core';
import StarterKit from '@tiptap/starter-kit';
import Placeholder from '@tiptap/extension-placeholder';
import { CodeInline } from './nodes/codeInline';
import { SeeRef } from './nodes/seeRef';
import { ParamRef } from './nodes/paramRef';
import { TypeParamRef } from './nodes/typeParamRef';
import { bridge } from './bridge';
import type { DocModel, ElementInfo, ParamDoc, TypeParamDoc } from './types';
import { initToolbar, setActiveEditor, updateToolbarState } from './toolbar';

// ────────────────────────────────────────────
// State
// ────────────────────────────────────────────
let currentElement: ElementInfo | null = null;
let currentDoc: DocModel = { summary: '' };
let summaryEditor: Editor | null = null;
let remarksEditor: Editor | null = null;
let returnsEditor: Editor | null = null;
let valueEditor: Editor | null = null;

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

function escapeXml(text: string): string {
  return text
    .replace(/&/g, '&amp;')
    .replace(/</g, '&lt;')
    .replace(/>/g, '&gt;')
    .replace(/"/g, '&quot;');
}

function escapeHtml(text: string): string {
  return text
    .replace(/&/g, '&amp;')
    .replace(/</g, '&lt;')
    .replace(/>/g, '&gt;')
    .replace(/"/g, '&quot;');
}

// ────────────────────────────────────────────
// Serialization: TipTap → XML-aware text
// ────────────────────────────────────────────
function serializeContent(editor: Editor): string {
  const blocks: string[] = [];
  editor.state.doc.forEach(block => {
    if (block.type.name === 'paragraph') {
      blocks.push(serializeBlock(block));
    }
  });
  return blocks.join('\n');
}

function serializeBlock(node: any): string {
  let result = '';
  node.forEach((child: any) => {
    if (!child.isText || !child.text) return;

    const text: string = child.text;
    const marks: any[] = child.marks;

    const codeInline = marks.find((m: any) => m.type.name === 'codeInline');
    const seeRef = marks.find((m: any) => m.type.name === 'seeRef');
    const paramRef = marks.find((m: any) => m.type.name === 'paramRef');
    const typeParamRef = marks.find((m: any) => m.type.name === 'typeParamRef');

    if (codeInline) {
      result += `<c>${escapeXml(text)}</c>`;
    } else if (seeRef) {
      const cref = seeRef.attrs.cref || text;
      result += `<see cref="${escapeXml(cref)}">${escapeXml(text)}</see>`;
    } else if (paramRef) {
      result += `<paramref name="${escapeXml(paramRef.attrs.name)}"/>`;
    } else if (typeParamRef) {
      result += `<typeparamref name="${escapeXml(typeParamRef.attrs.name)}"/>`;
    } else {
      result += escapeXml(text);
    }
  });
  return result;
}

// ────────────────────────────────────────────
// Deserialization: XML-aware text → TipTap HTML
// ────────────────────────────────────────────
/** inline XML 태그가 포함된 텍스트를 TipTap HTML로 변환 */
function textToHtml(text: string): string {
  if (!text) return '';
  const lines = text.split('\n');
  return lines
    .filter(line => line.trim() !== '')
    .map(line => `<p>${inlineXmlToHtml(line)}</p>`)
    .join('');
}

/** inline XML 태그를 TipTap 마크 HTML 요소로 변환 */
function inlineXmlToHtml(text: string): string {
  const pattern = /<c>(.*?)<\/c>|<see\s+cref="([^"]*)">(.*?)<\/see>|<see\s+cref="([^"]*)"\/?>|<paramref\s+name="([^"]*)"\/?>|<typeparamref\s+name="([^"]*)"\/?>/g;

  let result = '';
  let lastIndex = 0;
  let match;

  while ((match = pattern.exec(text)) !== null) {
    // 매치 앞의 일반 텍스트 (이미 XML 이스케이프됨 → HTML에서 유효)
    if (match.index > lastIndex) {
      result += text.slice(lastIndex, match.index);
    }

    if (match[1] !== undefined) {
      // <c>...</c>
      result += `<code class="xml-c">${match[1]}</code>`;
    } else if (match[2] !== undefined) {
      // <see cref="X">text</see>
      result += `<span class="see-ref" data-cref="${match[2]}" title="${match[2]}">${match[3]}</span>`;
    } else if (match[4] !== undefined) {
      // <see cref="X"/>
      result += `<span class="see-ref" data-cref="${match[4]}" title="${match[4]}">${match[4]}</span>`;
    } else if (match[5] !== undefined) {
      // <paramref name="X"/>
      result += `<span class="param-ref" data-param="${match[5]}">${match[5]}</span>`;
    } else if (match[6] !== undefined) {
      // <typeparamref name="T"/>
      result += `<span class="typeparam-ref" data-typeparam="${match[6]}">${match[6]}</span>`;
    }

    lastIndex = match.index + match[0].length;
  }

  if (lastIndex < text.length) {
    result += text.slice(lastIndex);
  }

  return result;
}

// ────────────────────────────────────────────
// Collect Document
// ────────────────────────────────────────────
function collectDoc(): DocModel {
  const doc: DocModel = {
    summary: summaryEditor ? serializeContent(summaryEditor) : '',
  };

  const remarksText = remarksEditor ? serializeContent(remarksEditor) : '';
  if (remarksText) doc.remarks = remarksText;

  const returnsText = returnsEditor ? serializeContent(returnsEditor) : '';
  if (returnsText) doc.returns = returnsText;

  const valueText = valueEditor ? serializeContent(valueEditor) : '';
  if (valueText) doc.value = valueText;

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

  // TypeParams
  const tpRows = document.querySelectorAll('.typeparam-row');
  if (tpRows.length > 0) {
    doc.typeParams = [];
    tpRows.forEach(row => {
      const name = row.querySelector('.typeparam-name')?.textContent ?? '';
      const desc = (row.querySelector('.typeparam-desc') as HTMLElement)?.innerText ?? '';
      doc.typeParams!.push({ name, description: desc });
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
  const kindLabel = escapeHtml(el.methodKind ?? el.kind);
  const parentLabel = el.qualifiedParent ? escapeHtml(el.qualifiedParent) + '.' : '';
  const nameLabel = escapeHtml(el.name);
  const fileLabel = escapeHtml(el.fileName ?? '');
  const lineLabel = el.lineNumber ? ` / ${el.lineNumber}` : '';
  header.innerHTML = `
    <span class="element-kind">${kindLabel}</span>
    <span class="element-name">${parentLabel}${nameLabel}</span>
    <span class="element-line">${fileLabel}${lineLabel}</span>
  `;
}

function renderParams(params: ParamDoc[], elementParams: ElementInfo['params']): void {
  const container = $('#params-section .section-body')!;
  container.innerHTML = '';

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
      <span class="param-name" title="${escapeHtml(sp.type ?? '')}">${escapeHtml(sp.name)}</span>
      <span class="param-desc" contenteditable="true" data-placeholder="설명...">${escapeHtml(docParam?.description ?? '')}</span>
    `;
    row.querySelector('.param-desc')!.addEventListener('input', notifyChanged);
    container.appendChild(row);
  });
}

function renderTypeParams(typeParams: TypeParamDoc[], genericParams: string[] | undefined): void {
  const container = $('#typeparams-section .section-body')!;
  container.innerHTML = '';

  const sigTypeParams = genericParams ?? [];
  if (sigTypeParams.length === 0) {
    $('#typeparams-section')!.classList.add('hidden');
    return;
  }
  $('#typeparams-section')!.classList.remove('hidden');

  sigTypeParams.forEach(name => {
    const docTP = typeParams.find(tp => tp.name === name);
    const row = document.createElement('div');
    row.className = 'typeparam-row';
    row.innerHTML = `
      <span class="typeparam-name">${escapeHtml(name)}</span>
      <span class="typeparam-desc" contenteditable="true" data-placeholder="설명...">${escapeHtml(docTP?.description ?? '')}</span>
    `;
    row.querySelector('.typeparam-desc')!.addEventListener('input', notifyChanged);
    container.appendChild(row);
  });
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
    <span class="example-desc" contenteditable="true" data-placeholder="설명 (선택)...">${escapeHtml(description)}</span>
    <textarea class="example-code" placeholder="코드 예시..." rows="3">${escapeHtml(code)}</textarea>
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
    <input class="exception-type" value="${escapeHtml(typeRef)}" placeholder="예외 타입 (예: EArgumentException)" />
    <span class="exception-desc" contenteditable="true" data-placeholder="설명...">${escapeHtml(description)}</span>
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
    <input class="seealso-cref" value="${escapeHtml(cref)}" placeholder="참조 (예: TMyClass.DoWork)" />
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
  $('#btn-add-example')?.addEventListener('click', () => {
    const container = $('#examples-section .section-body')!;
    addExampleRow(container);
    $('#examples-section')!.classList.remove('collapsed');
    notifyChanged();
  });

  $('#btn-add-exception')?.addEventListener('click', () => {
    const container = $('#exceptions-section .section-body')!;
    addExceptionRow(container);
    $('#exceptions-section')!.classList.remove('collapsed');
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
  summaryEditor?.destroy();
  summaryEditor = createEditor(
    $('#summary-editor')!,
    doc.summary,
    '요약 설명을 입력하세요...'
  );

  remarksEditor?.destroy();
  remarksEditor = createEditor(
    $('#remarks-editor')!,
    doc.remarks ?? '',
    '추가 설명...'
  );

  returnsEditor?.destroy();
  returnsEditor = createEditor(
    $('#returns-editor')!,
    doc.returns ?? '',
    '반환값 설명...'
  );

  valueEditor?.destroy();
  valueEditor = createEditor(
    $('#value-editor')!,
    doc.value ?? '',
    '프로퍼티 값 설명...'
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
  renderTypeParams(doc.typeParams ?? [], element.genericParams);

  // Returns/Value 섹션 가시성
  const hasReturn = element.kind === 'method' && !!element.returnType;
  const isProperty = element.kind === 'property';
  $('#returns-section')!.classList.toggle('hidden', !hasReturn);
  $('#value-section')!.classList.toggle('hidden', !isProperty);

  renderExamples(doc.examples);
  renderExceptions(doc.exceptions);
  renderSeeAlso(doc.seeAlso);
  updateToolbarState(element);

  // 데이터가 있는 접이식 섹션 자동 펼침
  if (doc.remarks) {
    $('#remarks-section')!.classList.remove('collapsed');
  }
  if ((doc.examples ?? []).length > 0) {
    $('#examples-section')!.classList.remove('collapsed');
  }
  if ((doc.exceptions ?? []).length > 0) {
    $('#exceptions-section')!.classList.remove('collapsed');
  }
  if ((doc.seeAlso ?? []).length > 0) {
    $('#seealso-section')!.classList.remove('collapsed');
  }
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
        summary: '사용자 정보를 <c>업데이트</c>합니다.',
        params: [
          { name: 'AUserId', description: '대상 사용자 ID' },
          { name: 'ANewName', description: '새로운 이름' },
        ],
        typeParams: [
          { name: 'T', description: '사용자 타입' },
        ],
        returns: '<paramref name="AUserId"/>에 해당하는 사용자의 업데이트 성공 여부',
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
