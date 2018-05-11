<%--<%@ taglib prefix="c" uri="http://java.sun.com/jsp/jstl/core"%>--%>
<c:set var="contextPath" value="${pageContext.request.contextPath}" />

<!DOCTYPE html PUBLIC "-//W3C//DTD XHTML 1.0 Transitional//EN"
        "http://www.w3.org/TR/xhtml1/DTD/xhtml1-transitional.dtd">
<html xmlns="http://www.w3.org/1999/xhtml">
<head>
    <meta http-equiv="Content-Type" content="text/html; charset=utf-8"/>
    <title>Baraza Banking | Sign In </title>
    <!-- Latest compiled and minified CSS -->
    <link rel="stylesheet" href="https://cdnjs.cloudflare.com/ajax/libs/font-awesome/4.7.0/css/font-awesome.min.css">
    <link rel="stylesheet" href="https://maxcdn.bootstrapcdn.com/bootstrap/3.3.7/css/bootstrap.min.css"
          integrity="sha384-BVYiiSIFeK1dGmJRAkycuHAHRg32OmUcww7on3RYdg4Va+PmSTsz/K68vbdEjh4u" crossorigin="anonymous">

    <!--Bootstrap-->
    <link rel="stylesheet" href="./assets/fonts/login/font-awesome.css">
    <link rel="stylesheet" href="./assets/css/login/service.css">

    <!-- Jquery -->
    <script src="./assets/js/login/bootstrap.min.js"></script>
    <script src="./assets/js/login/jquery.min.js"></script>
    <script src="./assets/js/login/jquery/1.10.1/jquery.js"></script>



    <!-- Latest compiled and minified JavaScript -->
    <script src="https://maxcdn.bootstrapcdn.com/bootstrap/3.3.7/js/bootstrap.min.js"
            integrity="sha384-Tc5IQib027qvyjSMfHjOMaLkfuWVxZxUPnCJA7l2mCWNIpG9mGCD8wGNIcPD7Txa"
            crossorigin="anonymous"></script>
</head>
<body>

<div class="container backgroundImage">

    <div id="polina" class="col-sm-6">
        <h4 class="text-center">SIGN IN</h4>

        <div class="social text-center">
            <div class="row">
            </div>
        </div>

        <form class="form-horizontal login-form" method="POST" action="j_security_check">
            <div class="form-group has-success has-feedback">
                <div class="col-sm-12">
                    <input class="form-control placeholder-no-fix" autocomplete="off" placeholder="Username" id="j_username" name="j_username" autofocus="" required="" type="text">
                    <span class="glyphicon glyphicon-user form-control-feedback"></span>
                </div>
            </div>

            <div class="form-group has-success has-feedback">
                <div class="col-sm-12">
                    <input class="form-control placeholder-no-fix" autocomplete="off" placeholder="Password" id="j_password" name="j_password" required="" type="password">
                    <span class="glyphicon glyphicon-lock form-control-feedback"></span>
                </div>
            </div>

            <div class="form-group has-success has-feedback">
                <div class="col-sm-6">
    			<input type="submit" value="Sign In" class="btn btn-success btn-sm"/>
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
