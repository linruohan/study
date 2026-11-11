/// 业务错误：带上 HTTP 状态码和稳定的错误码，接口层直接翻译成 JSON。
export class HttpError extends Error {
  readonly statusCode: number;
  readonly code: string;

  /// 标记字段：即使模块被重复加载，也能认出这是业务错误。
  readonly isHttpError = true;

  constructor(statusCode: number, code: string, message: string) {
    super(message);
    this.name = 'HttpError';
    this.statusCode = statusCode;
    this.code = code;
  }
}
