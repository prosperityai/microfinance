<%--<%@ taglib prefix="c" uri="http://java.sun.com/jsp/jstl/core"%>--%>
<c:set var="contextPath" value="${pageContext.request.contextPath}" />
<%
session.removeAttribute("xmlcnf");
session.invalidate();
%>
<!DOCTYPE html PUBLIC "-//W3C//DTD XHTML 1.0 Transitional//EN"
        "http://www.w3.org/TR/xhtml1/DTD/xhtml1-transitional.dtd">
<html xmlns="http://www.w3.org/1999/xhtml">
<head>
    <meta http-equiv="Content-Type" content="text/html; charset=utf-8"/>
    <title>Baraza Banking | Logout</title>
    <!-- Latest compiled and minified CSS -->
    <link rel="stylesheet" href="https://cdnjs.cloudflare.com/ajax/libs/font-awesome/4.7.0/css/font-awesome.min.css">
    <link rel="stylesheet" href="https://maxcdn.bootstrapcdn.com/bootstrap/3.3.7/css/bootstrap.min.css"
          integrity="sha384-BVYiiSIFeK1dGmJRAkycuHAHRg32OmUcww7on3RYdg4Va+PmSTsz/K68vbdEjh4u" crossorigin="anonymous">
    <link rel="stylesheet" href="./assets/css/login/service.css">

    <!-- Optional theme -->


    <!-- Latest compiled and minified JavaScript -->
    <script src="https://maxcdn.bootstrapcdn.com/bootstrap/3.3.7/js/bootstrap.min.js"
            integrity="sha384-Tc5IQib027qvyjSMfHjOMaLkfuWVxZxUPnCJA7l2mCWNIpG9mGCD8wGNIcPD7Txa"
            crossorigin="anonymous"></script>
</head>
<body>

<div class="container backgroundImage">

    <div id="polina" class="col-sm-6">
        <h4 class="text-center"><i class="glyphicon glyphicon-log-out"></i></h4>

        <div class="social text-center">
            <div class="row">
            </div>
        </div>

        <form class="form-horizontal">

            <div class="alert alert-success">
                You are now logged out.
            </div>

            <div class="form-group has-success has-feedback">
                <div class="col-sm-6">
		    <a href="index.jsp" class="btn btn-success btn-sm" >Sign In</a>
		</div>
		<div class="col-sm-6">
		    <a href="subscription.jsp?view=1:0" class="btn btn-primary btn-sm" style="float:right;">Bank Subscription</a>
		</div>
            </div>


        </form>
        <br>

        <div class="text-right">
            <p>Forgot Password?<a href="./application.jsp?view=2:0"> Click here</a></p>
        </div>
    </div>
</div>

<%@ include file="./features.jsp" %>

<footer>
    <p>Copyright © 2017 | Baraza Banking product of DewCis | Powered by <a href="https://www.dewcis.com/"
                                                                           target="_blank">Dewcis Solutions</a> | All
        rights reserved.</p>
</footer>

</body>
</html>
