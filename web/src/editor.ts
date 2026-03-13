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
import { renderPreview } from './preview';

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
function textToHtml(text: string): string {
  if (!text) return '';
  const lines = text.split('\n');
  return lines
    .filter(line => line.trim() !== '')
    .map(line => `<p>${inlineXmlToHtml(line)}</p>`)
    .join('');
}

function inlineXmlToHtml(text: string): string {
  const pattern = /<c>(.*?)<\/c>|<see\s+cref="([^"]*)">(.*?)<\/see>|<see\s+cref="([^"]*)"\/?>|<paramref\s+name="([^"]*)"\/?>|<typeparamref\s+name="([^"]*)"\/?>/g;

  let result = '';
  let lastIndex = 0;
  let match;

  while ((match = pattern.exec(text)) !== null) {
    if (match.index > lastIndex) {
      result += text.slice(lastIndex, match.index);
    }

    if (match[1] !== undefined) {
      result += `<code class="xml-c">${match[1]}</code>`;
    } else if (match[2] !== undefined) {
      result += `<span class="see-ref" data-cref="${match[2]}" title="${match[2]}">${match[3]}</span>`;
    } else if (match[4] !== undefined) {
      result += `<span class="see-ref" data-cref="${match[4]}" title="${match[4]}">${match[4]}</span>`;
    } else if (match[5] !== undefined) {
      result += `<span class="param-ref" data-param="${match[5]}">${match[5]}</span>`;
    } else if (match[6] !== undefined) {
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
  const paramRows = document.querySelectorAll('#params-body tr');
  if (paramRows.length > 0) {
    doc.params = [];
    paramRows.forEach(row => {
      const name = row.querySelector('.td-name')?.textContent ?? '';
      const desc = (row.querySelector('.td-desc') as HTMLElement)?.innerText ?? '';
      doc.params!.push({ name, description: desc });
    });
  }

  // TypeParams
  const tpRows = document.querySelectorAll('#typeparams-body tr');
  if (tpRows.length > 0) {
    doc.typeParams = [];
    tpRows.forEach(row => {
      const name = row.querySelector('.td-name')?.textContent ?? '';
      const desc = (row.querySelector('.td-desc') as HTMLElement)?.innerText ?? '';
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
// Member Signature
// ────────────────────────────────────────────
function renderSignature(el: ElementInfo): void {
  const sig = $('#member-signature')!;
  const kind = el.methodKind ?? el.kind;
  const parent = el.qualifiedParent ? escapeHtml(el.qualifiedParent) : '';
  const name = escapeHtml(el.name);
  const generics = el.genericParams?.length
    ? `<span class="sig-generic">&lt;${el.genericParams.map(escapeHtml).join(', ')}&gt;</span>`
    : '';

  // Build parameter signature
  let paramSig = '';
  if (el.params?.length) {
    const params = el.params.map(p => escapeHtml(p.name)).join(', ');
    paramSig = `(${params})`;
  }

  const kindLabel = `<span class="sig-kind"> ${escapeHtml(kind.charAt(0).toUpperCase() + kind.slice(1))}</span>`;

  if (parent) {
    sig.innerHTML = `<span class="sig-parent">${parent}.</span>${name}${generics}${paramSig}${kindLabel}`;
  } else {
    sig.innerHTML = `${name}${generics}${paramSig}${kindLabel}`;
  }
}

// ────────────────────────────────────────────
// Render Sections
// ────────────────────────────────────────────
function renderParams(params: ParamDoc[], elementParams: ElementInfo['params']): void {
  const tbody = $('#params-body')!;
  tbody.innerHTML = '';

  const sigParams = elementParams ?? [];
  if (sigParams.length === 0) {
    $('#params-section')!.classList.add('hidden');
    return;
  }
  $('#params-section')!.classList.remove('hidden');

  sigParams.forEach(sp => {
    const docParam = params.find(p => p.name === sp.name);
    const tr = document.createElement('tr');
    tr.innerHTML = `
      <td class="td-name" title="${escapeHtml(sp.type ?? '')}">${escapeHtml(sp.name)}</td>
      <td class="td-desc" contenteditable="true">${escapeHtml(docParam?.description ?? '')}</td>
    `;
    tr.querySelector('.td-desc')!.addEventListener('input', notifyChanged);
    tbody.appendChild(tr);
  });
}

function renderTypeParams(typeParams: TypeParamDoc[], genericParams: string[] | undefined): void {
  const tbody = $('#typeparams-body')!;
  tbody.innerHTML = '';

  const sigTypeParams = genericParams ?? [];
  if (sigTypeParams.length === 0) {
    $('#typeparams-section')!.classList.add('hidden');
    return;
  }
  $('#typeparams-section')!.classList.remove('hidden');

  sigTypeParams.forEach(name => {
    const docTP = typeParams.find(tp => tp.name === name);
    const tr = document.createElement('tr');
    tr.innerHTML = `
      <td class="td-name">${escapeHtml(name)}</td>
      <td class="td-desc" contenteditable="true">${escapeHtml(docTP?.description ?? '')}</td>
    `;
    tr.querySelector('.td-desc')!.addEventListener('input', notifyChanged);
    tbody.appendChild(tr);
  });
}

function renderExamples(examples: DocModel['examples']): void {
  const container = $('#examples-body')!;
  container.innerHTML = '';
  (examples ?? []).forEach(ex => addExampleRow(container, ex.description, ex.code));
}

function addExampleRow(container: HTMLElement, description = '', code = ''): void {
  const row = document.createElement('div');
  row.className = 'example-row';
  row.innerHTML = `
    <div class="example-header">
      <span style="font-size:11px;color:var(--text-muted)">Example</span>
      <button class="btn-remove" title="Remove">&times;</button>
    </div>
    <div class="example-desc" contenteditable="true" data-placeholder="Description (optional)...">${escapeHtml(description)}</div>
    <textarea class="example-code" placeholder="Code example..." rows="3">${escapeHtml(code)}</textarea>
  `;
  row.querySelector('.example-desc')!.addEventListener('input', notifyChanged);
  row.querySelector('.example-code')!.addEventListener('input', notifyChanged);
  row.querySelector('.btn-remove')!.addEventListener('click', () => {
    row.remove();
    notifyChanged();
  });
  container.appendChild(row);
}

function renderExceptions(exceptions: DocModel['exceptions']): void {
  const container = $('#exceptions-body')!;
  container.innerHTML = '';
  (exceptions ?? []).forEach(ex => addExceptionRow(container, ex.typeRef, ex.description));
}

function addExceptionRow(container: HTMLElement, typeRef = '', description = ''): void {
  const row = document.createElement('div');
  row.className = 'exception-row';
  row.innerHTML = `
    <input class="exception-type" value="${escapeHtml(typeRef)}" placeholder="Exception type (e.g. EArgumentException)" />
    <span class="exception-desc" contenteditable="true" data-placeholder="Description...">${escapeHtml(description)}</span>
    <button class="btn-remove" title="Remove">&times;</button>
  `;
  row.querySelector('.exception-type')!.addEventListener('input', notifyChanged);
  row.querySelector('.exception-desc')!.addEventListener('input', notifyChanged);
  row.querySelector('.btn-remove')!.addEventListener('click', () => {
    row.remove();
    notifyChanged();
  });
  container.appendChild(row);
}

function renderSeeAlso(seeAlso: DocModel['seeAlso']): void {
  const container = $('#seealso-body')!;
  container.innerHTML = '';
  (seeAlso ?? []).forEach(sa => addSeeAlsoRow(container, sa.cref));
}

function addSeeAlsoRow(container: HTMLElement, cref = ''): void {
  const row = document.createElement('div');
  row.className = 'seealso-row';
  row.innerHTML = `
    <input class="seealso-cref" value="${escapeHtml(cref)}" placeholder="Reference (e.g. TMyClass.DoWork)" />
    <button class="btn-remove" title="Remove">&times;</button>
  `;
  row.querySelector('.seealso-cref')!.addEventListener('input', notifyChanged);
  row.querySelector('.btn-remove')!.addEventListener('click', () => {
    row.remove();
    notifyChanged();
  });
  container.appendChild(row);
}

// ────────────────────────────────────────────
// Section Collapsing
// ────────────────────────────────────────────
function setupCollapsible(): void {
  document.querySelectorAll('.doc-heading').forEach(heading => {
    heading.addEventListener('click', () => {
      const section = heading.parentElement!;
      section.classList.toggle('collapsed');
    });
  });
}

function setupAddButtons(): void {
  $('#btn-add-example')?.addEventListener('click', () => {
    addExampleRow($('#examples-body')!);
    notifyChanged();
  });

  $('#btn-add-exception')?.addEventListener('click', () => {
    addExceptionRow($('#exceptions-body')!);
    notifyChanged();
  });

  $('#btn-add-seealso')?.addEventListener('click', () => {
    addSeeAlsoRow($('#seealso-body')!);
    notifyChanged();
  });
}

// ────────────────────────────────────────────
// Tab Switching
// ────────────────────────────────────────────
function setupTabs(): void {
  document.querySelectorAll('#doc-tabs .tab').forEach(tab => {
    tab.addEventListener('click', () => {
      const target = (tab as HTMLElement).dataset.tab;

      document.querySelectorAll('#doc-tabs .tab').forEach(t => t.classList.remove('active'));
      tab.classList.add('active');

      if (target === 'design') {
        $('#doc-design')!.classList.remove('hidden');
        $('#doc-preview')!.classList.add('hidden');
      } else {
        $('#doc-design')!.classList.add('hidden');
        $('#doc-preview')!.classList.remove('hidden');
        renderPreview($('#doc-preview')!, collectDoc(), currentElement);
      }
    });
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
  summaryEditor = createEditor($('#summary-editor')!, doc.summary, 'Enter a summary description...');

  remarksEditor?.destroy();
  remarksEditor = createEditor($('#remarks-editor')!, doc.remarks ?? '', 'Additional remarks...');

  returnsEditor?.destroy();
  returnsEditor = createEditor($('#returns-editor')!, doc.returns ?? '', 'Return value description...');

  valueEditor?.destroy();
  valueEditor = createEditor($('#value-editor')!, doc.value ?? '', 'Property value description...');
}

// ────────────────────────────────────────────
// Load Document
// ────────────────────────────────────────────
export function loadDocument(element: ElementInfo, doc: DocModel): void {
  currentElement = element;
  currentDoc = doc;

  renderSignature(element);
  initEditors(doc);
  renderParams(doc.params ?? [], element.params);
  renderTypeParams(doc.typeParams ?? [], element.genericParams);

  // Return type display
  const hasReturn = element.kind === 'method' && !!element.returnType;
  const isProperty = element.kind === 'property';
  $('#returns-section')!.classList.toggle('hidden', !hasReturn);
  $('#value-section')!.classList.toggle('hidden', !isProperty);

  if (hasReturn && element.returnType) {
    $('#return-type')!.innerHTML = `Type: <strong>${escapeHtml(element.returnType)}</strong>`;
  }

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
  setupTabs();

  bridge.onElementLoaded((element, doc) => {
    loadDocument(element, doc);
  });

  // 디버깅용: 샘플 데이터 로드
  if (!((window as any).chrome?.webview)) {
    loadDocument(
      {
        kind: 'method',
        name: 'GetValueOrDefault',
        qualifiedParent: 'Nullable<T>',
        methodKind: 'function',
        params: [
          { name: 'defaultValue', type: 'T' },
        ],
        returnType: 'T',
        genericParams: ['T'],
      },
      {
        summary: 'Retrieves the value of the current <c>Nullable{T}</c> object, or the specified default value.',
        params: [
          { name: 'defaultValue', description: 'A value to return if the <see cref="HasValue">HasValue</see> property is false.' },
        ],
        typeParams: [
          { name: 'T', description: 'The underlying value type of the nullable type.' },
        ],
        returns: 'The value of the <see cref="Value">Value</see> property if the <see cref="HasValue">HasValue</see> property is true; otherwise, the <paramref name="defaultValue"/> parameter.',
        examples: [
          { description: 'Basic usage', code: 'var result = nullable.GetValueOrDefault(0);' },
        ],
        exceptions: [
          { typeRef: 'EInvalidOperation', description: 'Thrown when the value cannot be retrieved.' },
        ],
        seeAlso: [{ cref: 'Nullable<T>.HasValue' }],
      }
    );
  }
}
