import { NextResponse, type NextRequest } from 'next/server'

const SESSION_COOKIE = 'chocomint_admin'

export function middleware(request: NextRequest) {
  const token = request.cookies.get(SESSION_COOKIE)?.value
  if (token && token === process.env.ADMIN_SESSION_SECRET) {
    return NextResponse.next()
  }
  const url = request.nextUrl.clone()
  url.pathname = '/login'
  url.search = ''
  return NextResponse.redirect(url)
}

// /login と静的ファイル以外はすべてログインを要求する。
export const config = {
  matcher: ['/((?!login|_next/static|_next/image|favicon.ico).*)'],
}
