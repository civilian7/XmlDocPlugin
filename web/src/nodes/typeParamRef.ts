import { Mark, mergeAttributes } from '@tiptap/core';

/**
 * 제네릭 타입 파라미터 참조 마크 — XML <typeparamref name="..."> 태그에 대응.
 */
export const TypeParamRef = Mark.create({
  name: 'typeParamRef',
  inclusive: false,

  addAttributes() {
    return {
      name: {
        default: '',
        parseHTML: (el: HTMLElement) => el.getAttribute('data-typeparam') ?? '',
      },
    };
  },

  parseHTML() {
    return [{ tag: 'span.typeparam-ref' }];
  },

  renderHTML({ HTMLAttributes }) {
    return [
      'span',
      mergeAttributes(HTMLAttributes, {
        class: 'typeparam-ref',
        'data-typeparam': HTMLAttributes.name,
      }),
      0,
    ];
  },
});
