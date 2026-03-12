import { Mark, mergeAttributes } from '@tiptap/core';

/**
 * 파라미터 참조 마크 — XML <paramref name="..."> 태그에 대응.
 */
export const ParamRef = Mark.create({
  name: 'paramRef',
  inclusive: false,

  addAttributes() {
    return {
      name: {
        default: '',
        parseHTML: (el: HTMLElement) => el.getAttribute('data-param') ?? '',
      },
    };
  },

  parseHTML() {
    return [{ tag: 'span.param-ref' }];
  },

  renderHTML({ HTMLAttributes }) {
    return [
      'span',
      mergeAttributes(HTMLAttributes, {
        class: 'param-ref',
        'data-param': HTMLAttributes.name,
      }),
      0,
    ];
  },
});
