/** 코드 요소 종류 */
export type DocElementKind =
  | 'unit' | 'class' | 'record' | 'interface'
  | 'method' | 'property' | 'field' | 'type' | 'constant';

/** 파라미터 시그니처 정보 */
export interface ParamInfo {
  name: string;
  type: string;
  defaultValue?: string;
  isConst?: boolean;
  isVar?: boolean;
  isOut?: boolean;
}

/** 코드 요소 정보 (Delphi → WebView) */
export interface ElementInfo {
  kind: DocElementKind;
  name: string;
  fullName?: string;
  qualifiedParent?: string;
  methodKind?: string;
  params: ParamInfo[];
  returnType?: string;
  genericParams?: string[];
  visibility?: string;
  lineNumber?: number;
  fileName?: string;
}

/** 파라미터 문서 */
export interface ParamDoc {
  name: string;
  description: string;
}

/** 제네릭 타입 파라미터 문서 */
export interface TypeParamDoc {
  name: string;
  description: string;
}

/** 예외 문서 */
export interface ExceptionDoc {
  typeRef: string;
  description: string;
}

/** 예제 문서 */
export interface ExampleDoc {
  title?: string;
  code?: string;
  description: string;
}

/** See Also 문서 */
export interface SeeAlsoDoc {
  cref: string;
  description?: string;
}

/** 문서 모델 (Delphi ↔ WebView JSON 프로토콜) */
export interface DocModel {
  summary: string;
  remarks?: string;
  returns?: string;
  value?: string;
  params?: ParamDoc[];
  typeParams?: TypeParamDoc[];
  exceptions?: ExceptionDoc[];
  examples?: ExampleDoc[];
  seeAlso?: SeeAlsoDoc[];
}

/** Delphi → WebView 메시지 */
export type InboundMessage =
  | { type: 'loadDoc'; data: { element: ElementInfo; doc: DocModel } }
  | { type: 'elementChanged'; data: { element: ElementInfo } };

/** WebView → Delphi 메시지 */
export type OutboundMessage =
  | { type: 'docUpdated'; doc: DocModel }
  | { type: 'requestAutoComplete'; prefix: string; context: string };
