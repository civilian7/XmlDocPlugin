import { Mark, mergeAttributes } from '@tiptap/core';

/**
 * See 참조 마크 — XML <see cref="..."> 태그에 대응.
 * 타입/멤버 참조 링크를 표현합니다.
 */
export const SeeRef = Mark.create({
  name: 'seeRef',
  inclusive: false,

  addAttributes() {
    return {
      cref: { default: '' },
    };
  },

  parseHTML() {
    return [{ tag: 'span.see-ref' }];
  },

  renderHTML({ HTMLAttributes }) {
    return [
      'span',
      mergeAttributes(HTMLAttributes, {
        class: 'see-ref',
        'data-cref': HTMLAttributes.cref,
        title: HTMLAttributes.cref,
      }),
      0,
    ];
  },
});
