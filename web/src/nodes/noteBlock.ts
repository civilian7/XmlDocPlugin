import { Node, mergeAttributes } from '@tiptap/core';

/**
 * 주의사항 블록 노드 — XML <note> 태그에 대응.
 */
export const NoteBlock = Node.create({
  name: 'noteBlock',
  group: 'block',
  content: 'inline*',

  addAttributes() {
    return {
      noteType: { default: 'note' }, // note, warning, caution, tip
    };
  },

  parseHTML() {
    return [{ tag: 'div.note-block' }];
  },

  renderHTML({ HTMLAttributes }) {
    return [
      'div',
      mergeAttributes(HTMLAttributes, {
        class: `note-block note-${HTMLAttributes.noteType}`,
      }),
      0,
    ];
  },
});
