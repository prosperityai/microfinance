/*
 * Generated by the Jasper component of Apache Tomcat
 * Version: Apache Tomcat/8.5.24
 * Generated at: 2018-03-20 13:33:57 UTC
 * Note: The last modified time of this file was set to
 *       the last modified time of the source file after
 *       generation to assist with modification tracking.
 */
package org.apache.jsp;

import javax.servlet.*;
import javax.servlet.http.*;
import javax.servlet.jsp.*;

public final class logon_jsp extends org.apache.jasper.runtime.HttpJspBase
    implements org.apache.jasper.runtime.JspSourceDependent,
                 org.apache.jasper.runtime.JspSourceImports {

  private static final javax.servlet.jsp.JspFactory _jspxFactory =
          javax.servlet.jsp.JspFactory.getDefaultFactory();

  private static java.util.Map<java.lang.String,java.lang.Long> _jspx_dependants;

  static {
    _jspx_dependants = new java.util.HashMap<java.lang.String,java.lang.Long>(1);
    _jspx_dependants.put("/./features.jsp", Long.valueOf(1502795070000L));
  }

  private static final java.util.Set<java.lang.String> _jspx_imports_packages;

  private static final java.util.Set<java.lang.String> _jspx_imports_classes;

  static {
    _jspx_imports_packages = new java.util.HashSet<>();
    _jspx_imports_packages.add("javax.servlet");
    _jspx_imports_packages.add("javax.servlet.http");
    _jspx_imports_packages.add("javax.servlet.jsp");
    _jspx_imports_classes = null;
  }

  private volatile javax.el.ExpressionFactory _el_expressionfactory;
  private volatile org.apache.tomcat.InstanceManager _jsp_instancemanager;

  public java.util.Map<java.lang.String,java.lang.Long> getDependants() {
    return _jspx_dependants;
  }

  public java.util.Set<java.lang.String> getPackageImports() {
    return _jspx_imports_packages;
  }

  public java.util.Set<java.lang.String> getClassImports() {
    return _jspx_imports_classes;
  }

  public javax.el.ExpressionFactory _jsp_getExpressionFactory() {
    if (_el_expressionfactory == null) {
      synchronized (this) {
        if (_el_expressionfactory == null) {
          _el_expressionfactory = _jspxFactory.getJspApplicationContext(getServletConfig().getServletContext()).getExpressionFactory();
        }
      }
    }
    return _el_expressionfactory;
  }

  public org.apache.tomcat.InstanceManager _jsp_getInstanceManager() {
    if (_jsp_instancemanager == null) {
      synchronized (this) {
        if (_jsp_instancemanager == null) {
          _jsp_instancemanager = org.apache.jasper.runtime.InstanceManagerFactory.getInstanceManager(getServletConfig());
        }
      }
    }
    return _jsp_instancemanager;
  }

  public void _jspInit() {
  }

  public void _jspDestroy() {
  }

  public void _jspService(final javax.servlet.http.HttpServletRequest request, final javax.servlet.http.HttpServletResponse response)
      throws java.io.IOException, javax.servlet.ServletException {

    final java.lang.String _jspx_method = request.getMethod();
    if (!"GET".equals(_jspx_method) && !"POST".equals(_jspx_method) && !"HEAD".equals(_jspx_method) && !javax.servlet.DispatcherType.ERROR.equals(request.getDispatcherType())) {
      response.sendError(HttpServletResponse.SC_METHOD_NOT_ALLOWED, "JSPs only permit GET POST or HEAD");
      return;
    }

    final javax.servlet.jsp.PageContext pageContext;
    javax.servlet.http.HttpSession session = null;
    final javax.servlet.ServletContext application;
    final javax.servlet.ServletConfig config;
    javax.servlet.jsp.JspWriter out = null;
    final java.lang.Object page = this;
    javax.servlet.jsp.JspWriter _jspx_out = null;
    javax.servlet.jsp.PageContext _jspx_page_context = null;


    try {
      response.setContentType("text/html");
      pageContext = _jspxFactory.getPageContext(this, request, response,
      			null, true, 8192, true);
      _jspx_page_context = pageContext;
      application = pageContext.getServletContext();
      config = pageContext.getServletConfig();
      session = pageContext.getSession();
      out = pageContext.getOut();
      _jspx_out = out;

      out.write("\r\n");
      out.write("<c:set var=\"contextPath\" value=\"");
      out.write((java.lang.String) org.apache.jasper.runtime.PageContextImpl.proprietaryEvaluate("${pageContext.request.contextPath}", java.lang.String.class, (javax.servlet.jsp.PageContext)_jspx_page_context, null));
      out.write("\" />\r\n");
      out.write("\r\n");
      out.write("<!DOCTYPE html PUBLIC \"-//W3C//DTD XHTML 1.0 Transitional//EN\"\r\n");
      out.write("        \"http://www.w3.org/TR/xhtml1/DTD/xhtml1-transitional.dtd\">\r\n");
      out.write("<html xmlns=\"http://www.w3.org/1999/xhtml\">\r\n");
      out.write("<head>\r\n");
      out.write("    <meta http-equiv=\"Content-Type\" content=\"text/html; charset=utf-8\"/>\r\n");
      out.write("    <title>Baraza Banking | Sign In </title>\r\n");
      out.write("    <!-- Latest compiled and minified CSS -->\r\n");
      out.write("    <link rel=\"stylesheet\" href=\"https://cdnjs.cloudflare.com/ajax/libs/font-awesome/4.7.0/css/font-awesome.min.css\">\r\n");
      out.write("    <link rel=\"stylesheet\" href=\"https://maxcdn.bootstrapcdn.com/bootstrap/3.3.7/css/bootstrap.min.css\"\r\n");
      out.write("          integrity=\"sha384-BVYiiSIFeK1dGmJRAkycuHAHRg32OmUcww7on3RYdg4Va+PmSTsz/K68vbdEjh4u\" crossorigin=\"anonymous\">\r\n");
      out.write("\r\n");
      out.write("    <!--Bootstrap-->\r\n");
      out.write("    <link rel=\"stylesheet\" href=\"./assets/fonts/login/font-awesome.css\">\r\n");
      out.write("    <link rel=\"stylesheet\" href=\"./assets/css/login/service.css\">\r\n");
      out.write("\r\n");
      out.write("    <!-- Jquery -->\r\n");
      out.write("    <script src=\"./assets/js/login/bootstrap.min.js\"></script>\r\n");
      out.write("    <script src=\"./assets/js/login/jquery.min.js\"></script>\r\n");
      out.write("    <script src=\"./assets/js/login/jquery/1.10.1/jquery.js\"></script>\r\n");
      out.write("\r\n");
      out.write("\r\n");
      out.write("\r\n");
      out.write("    <!-- Latest compiled and minified JavaScript -->\r\n");
      out.write("    <script src=\"https://maxcdn.bootstrapcdn.com/bootstrap/3.3.7/js/bootstrap.min.js\"\r\n");
      out.write("            integrity=\"sha384-Tc5IQib027qvyjSMfHjOMaLkfuWVxZxUPnCJA7l2mCWNIpG9mGCD8wGNIcPD7Txa\"\r\n");
      out.write("            crossorigin=\"anonymous\"></script>\r\n");
      out.write("</head>\r\n");
      out.write("<body>\r\n");
      out.write("\r\n");
      out.write("<div class=\"container backgroundImage\">\r\n");
      out.write("\r\n");
      out.write("    <div id=\"polina\" class=\"col-sm-6\">\r\n");
      out.write("        <h4 class=\"text-center\">SIGN IN</h4>\r\n");
      out.write("\r\n");
      out.write("        <div class=\"social text-center\">\r\n");
      out.write("            <div class=\"row\">\r\n");
      out.write("            </div>\r\n");
      out.write("        </div>\r\n");
      out.write("\r\n");
      out.write("        <form class=\"form-horizontal login-form\" method=\"POST\" action=\"j_security_check\">\r\n");
      out.write("            <div class=\"form-group has-success has-feedback\">\r\n");
      out.write("                <div class=\"col-sm-12\">\r\n");
      out.write("                    <input class=\"form-control placeholder-no-fix\" autocomplete=\"off\" placeholder=\"Username\" id=\"j_username\" name=\"j_username\" autofocus=\"\" required=\"\" type=\"text\">\r\n");
      out.write("                    <span class=\"glyphicon glyphicon-user form-control-feedback\"></span>\r\n");
      out.write("                </div>\r\n");
      out.write("            </div>\r\n");
      out.write("\r\n");
      out.write("            <div class=\"form-group has-success has-feedback\">\r\n");
      out.write("                <div class=\"col-sm-12\">\r\n");
      out.write("                    <input class=\"form-control placeholder-no-fix\" autocomplete=\"off\" placeholder=\"Password\" id=\"j_password\" name=\"j_password\" required=\"\" type=\"password\">\r\n");
      out.write("                    <span class=\"glyphicon glyphicon-lock form-control-feedback\"></span>\r\n");
      out.write("                </div>\r\n");
      out.write("            </div>\r\n");
      out.write("\r\n");
      out.write("            <div class=\"form-group has-success has-feedback\">\r\n");
      out.write("                <div class=\"col-sm-6\">\r\n");
      out.write("    \t\t\t<input type=\"submit\" value=\"Sign In\" class=\"btn btn-success btn-sm\"/>\r\n");
      out.write("\t\t</div>\r\n");
      out.write("\t\t<div class=\"col-sm-6\">\r\n");
      out.write("\t\t    <a href=\"subscription.jsp?view=1:0\" class=\"btn btn-primary btn-sm\" style=\"float:right;\">Bank Subscription</a>\r\n");
      out.write("\t\t</div>\r\n");
      out.write("            </div>\r\n");
      out.write("\r\n");
      out.write("        </form>\r\n");
      out.write("        <br>\r\n");
      out.write("\r\n");
      out.write("        <div class=\"text-right\">\r\n");
      out.write("            <p>Forgot Password?<a href=\"./application.jsp?view=2:0\"> Click here</a></p>\r\n");
      out.write("        </div>\r\n");
      out.write("    </div>\r\n");
      out.write("</div>\r\n");
      out.write("\r\n");
      out.write("    <div class=\"service-wrapper\">\r\n");
      out.write("        <div class=\" container\">\r\n");
      out.write("        <div class=\"row\">\r\n");
      out.write("\r\n");
      out.write("        <div class=\"col-md-12  text-center\">\r\n");
      out.write("        <h2 class=\"text-uppercase\">Features</h2>\r\n");
      out.write("\r\n");
      out.write("        <div class=\"divider\"></div>\r\n");
      out.write("        </div>\r\n");
      out.write("\r\n");
      out.write("        <div class=\"col-md-4 col-sm-6 col-xsx-6\">\r\n");
      out.write("        <div class=\"serviceBox\">\r\n");
      out.write("        <div class=\"service-icon\">\r\n");
      out.write("        <span><i class=\"glyphicon glyphicon-download-alt\"></i></span>\r\n");
      out.write("        </div>\r\n");
      out.write("        <div class=\"service-content\">\r\n");
      out.write("        <h3 class=\"title\">Deposits</h3>\r\n");
      out.write("\r\n");
      out.write("        <p class=\"description\">All deposits transactions are recorded here. They are either in cash,\r\n");
      out.write("        cheques or direct transfers. The summary can be extracted after every transactions, most\r\n");
      out.write("        customers will have monthly reports of these transactions.\r\n");
      out.write("        </p>\r\n");
      out.write("        <a href=\"#\" class=\"read-more fa fa-plus\" data-toggle=\"tooltip\" title=\"Read More\"></a>\r\n");
      out.write("        </div>\r\n");
      out.write("        </div>\r\n");
      out.write("        </div>\r\n");
      out.write("\r\n");
      out.write("        <div class=\"col-md-4 col-sm-6 col-xsx-6\">\r\n");
      out.write("        <div class=\"serviceBox green\">\r\n");
      out.write("        <div class=\"service-icon\">\r\n");
      out.write("        <span><i class=\"glyphicon glyphicon-piggy-bank\"></i></span>\r\n");
      out.write("        </div>\r\n");
      out.write("        <div class=\"service-content\">\r\n");
      out.write("        <h3 class=\"title\">Savings</h3>\r\n");
      out.write("\r\n");
      out.write("        <p class=\"description\">Customers deposits monies set aside as savings. These will mostly\r\n");
      out.write("        be put in a Savings account and are meant for a certain purpose, with a fixed time of\r\n");
      out.write("        saving before any withdrawals are done. Customers can extract their savings reports here.\r\n");
      out.write("        </p>\r\n");
      out.write("        <a href=\"#\" class=\"read-more fa fa-plus\" data-toggle=\"tooltip\" title=\"Read More\"></a>\r\n");
      out.write("        </div>\r\n");
      out.write("        </div>\r\n");
      out.write("        </div>\r\n");
      out.write("\r\n");
      out.write("        <div class=\"col-md-4 col-sm-6 col-xsx-6\">\r\n");
      out.write("        <div class=\"serviceBox orange\">\r\n");
      out.write("        <div class=\"service-icon\">\r\n");
      out.write("        <span><i class=\" \tglyphicon glyphicon-check\"></i></span>\r\n");
      out.write("        </div>\r\n");
      out.write("        <div class=\"service-content\">\r\n");
      out.write("        <h3 class=\"title\">Loans</h3>\r\n");
      out.write("\r\n");
      out.write("        <p class=\"description\">Customers are allowed to borrow money against their savings and/or\r\n");
      out.write("        their salary. The reason for this is that they are required to have a collateral\r\n");
      out.write("        against borrowed amounts. These transactions and verifications are done here.\r\n");
      out.write("        A customer is able to access their loan reports here.\r\n");
      out.write("        </p>\r\n");
      out.write("        <a href=\"#\" class=\"read-more fa fa-plus\" data-toggle=\"tooltip\" title=\"Read More\"></a>\r\n");
      out.write("        </div>\r\n");
      out.write("        </div>\r\n");
      out.write("        </div>\r\n");
      out.write("        </div>\r\n");
      out.write("        </div>\r\n");
      out.write("        </div>");
      out.write("\r\n");
      out.write("\r\n");
      out.write("<footer>\r\n");
      out.write("    <p>Copyright Â© 2017 | Baraza Banking product of DewCis | Powered by <a href=\"https://www.dewcis.com/\"\r\n");
      out.write("                                                                           target=\"_blank\">Dewcis Solutions</a> | All\r\n");
      out.write("        rights reserved.</p>\r\n");
      out.write("</footer>\r\n");
      out.write("\r\n");
      out.write("</body>\r\n");
      out.write("</html>\r\n");
    } catch (java.lang.Throwable t) {
      if (!(t instanceof javax.servlet.jsp.SkipPageException)){
        out = _jspx_out;
        if (out != null && out.getBufferSize() != 0)
          try {
            if (response.isCommitted()) {
              out.flush();
            } else {
              out.clearBuffer();
            }
          } catch (java.io.IOException e) {}
        if (_jspx_page_context != null) _jspx_page_context.handlePageException(t);
        else throw new ServletException(t);
      }
    } finally {
      _jspxFactory.releasePageContext(_jspx_page_context);
    }
  }
}
