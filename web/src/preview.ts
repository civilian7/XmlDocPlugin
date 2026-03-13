import type { DocModel, ElementInfo } from './types';

function esc(text: string): string {
  return text
    .replace(/&/g, '&amp;')
    .replace(/</g, '&lt;')
    .replace(/>/g, '&gt;')
    .replace(/"/g, '&quot;');
}

/** inline XML 태그를 Preview용 HTML로 변환 */
function inlineToPreviewHtml(text: string): string {
  return text
    .replace(/<c>(.*?)<\/c>/g, '<span class="preview-code-ref">$1</span>')
    .replace(/<see\s+cref="([^"]*)">(.*?)<\/see>/g, '<span class="preview-see-ref">$2</span>')
    .replace(/<see\s+cref="([^"]*)"\/?\s*>/g, '<span class="preview-see-ref">$1</span>')
    .replace(/<paramref\s+name="([^"]*)"\/?\s*>/g, '<strong>$1</strong>')
    .replace(/<typeparamref\s+name="([^"]*)"\/?\s*>/g, '<em>$1</em>');
}

function textToPreviewP(text: string): string {
  if (!text) return '';
  return text
    .split('\n')
    .filter(l => l.trim())
    .map(l => `<p>${inlineToPreviewHtml(l)}</p>`)
    .join('');
}

export function renderPreview(
  container: HTMLElement,
  doc: DocModel,
  element: ElementInfo | null,
): void {
  let html = '';

  // Summary
  if (doc.summary) {
    html += `<h2>Summary</h2>`;
    html += textToPreviewP(doc.summary);
  }

  // Parameters
  if (doc.params?.length) {
    html += `<h2>Parameters</h2>`;
    html += `<table><thead><tr><th>Parameter</th><th>Description</th></tr></thead><tbody>`;
    doc.params.forEach(p => {
      html += `<tr><td><strong>${esc(p.name)}</strong></td><td>${inlineToPreviewHtml(p.description)}</td></tr>`;
    });
    html += `</tbody></table>`;
  }

  // Type Parameters
  if (doc.typeParams?.length) {
    html += `<h2>Type Parameters</h2>`;
    html += `<table><thead><tr><th>Type Parameter</th><th>Description</th></tr></thead><tbody>`;
    doc.typeParams.forEach(tp => {
      html += `<tr><td><em>${esc(tp.name)}</em></td><td>${inlineToPreviewHtml(tp.description)}</td></tr>`;
    });
    html += `</tbody></table>`;
  }

  // Returns
  if (doc.returns) {
    html += `<h2>Return Value</h2>`;
    if (element?.returnType) {
      html += `<p>Type: <strong>${esc(element.returnType)}</strong></p>`;
    }
    html += textToPreviewP(doc.returns);
  }

  // Value
  if (doc.value) {
    html += `<h2>Value</h2>`;
    html += textToPreviewP(doc.value);
  }

  // Remarks
  if (doc.remarks) {
    html += `<h2>Remarks</h2>`;
    html += textToPreviewP(doc.remarks);
  }

  // Examples
  if (doc.examples?.length) {
    html += `<h2>Examples</h2>`;
    doc.examples.forEach(ex => {
      if (ex.description) {
        html += `<p>${inlineToPreviewHtml(ex.description)}</p>`;
      }
      if (ex.code) {
        html += `<pre>${esc(ex.code)}</pre>`;
      }
    });
  }

  // Exceptions
  if (doc.exceptions?.length) {
    html += `<h2>Exceptions</h2>`;
    html += `<table><thead><tr><th>Exception</th><th>Condition</th></tr></thead><tbody>`;
    doc.exceptions.forEach(ex => {
      html += `<tr><td><strong>${esc(ex.typeRef)}</strong></td><td>${inlineToPreviewHtml(ex.description)}</td></tr>`;
    });
    html += `</tbody></table>`;
  }

  // See Also
  if (doc.seeAlso?.length) {
    html += `<h2>See Also</h2>`;
    html += `<ul>`;
    doc.seeAlso.forEach(sa => {
      html += `<li><span class="preview-see-ref">${esc(sa.cref)}</span></li>`;
    });
    html += `</ul>`;
  }

  container.innerHTML = html || '<p style="color: var(--text-muted)">No documentation content.</p>';
}
