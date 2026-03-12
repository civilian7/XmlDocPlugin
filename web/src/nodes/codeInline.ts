import { Mark, mergeAttributes } from '@tiptap/core';

/**
 * 인라인 코드 마크 — XML <c> 태그에 대응.
 * TipTap 기본 Code 확장 대신 사용하여 XML 직렬화를 제어합니다.
 */
export const CodeInline = Mark.create({
  name: 'codeInline',
  excludes: '_',
  code: true,

  parseHTML() {
    return [{ tag: 'code.xml-c' }];
  },

  renderHTML({ HTMLAttributes }) {
    return ['code', mergeAttributes(HTMLAttributes, { class: 'xml-c' }), 0];
  },

  addKeyboardShortcuts() {
    return {
      'Mod-e': () => this.editor.commands.toggleMark(this.name),
    };
  },
});
