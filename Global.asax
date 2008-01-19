<%@ Import Namespace="System.IO" %>
<%@ Import Namespace="btnet" %>
<script runat="server" language="C#">

/*
Copyright 2002 Corey Trager 
Distributed under the terms of the GNU General Public License
*/

string prev_day = DateTime.Now.ToString("yyyy-MM-dd");

public void Application_Error(Object sender, EventArgs e)
{

	Exception exc = Server.GetLastError().GetBaseException();

	bool log_enabled = (Util.get_setting("LogEnabled","1") == "1");
	if (log_enabled)
	{

		string path = Util.get_log_file_path();
		
		// open file
		StreamWriter w = File.AppendText(path);
		
		w.WriteLine("\nTIME: "  + DateTime.Now.ToLongTimeString());
		w.WriteLine("MSG: " + exc.Message.ToString());
		w.WriteLine("URL: " + Request.Url.ToString());
		w.WriteLine("EXCEPTION: " + exc.ToString());
		
		w.Close();
	}
	
	bool error_email_enabled = (btnet.Util.get_setting("ErrorEmailEnabled","1") == "1");
	if (error_email_enabled)
	{
		string to = Util.get_setting("ErrorEmailTo","");
		string from = Util.get_setting("ErrorEmailFrom","");
		string subject = "Error: " + exc.Message.ToString();
		string body = "\nTIME: "
			+ DateTime.Now.ToLongTimeString()
			+ "\nURL: "
			+ Request.Url.ToString()
			+ "\nException: "
			+ exc.ToString();

		btnet.Email.send_email(to, from, "", subject, body); // 5 args				
	}
}
     
public void Application_OnStart(Object sender, EventArgs e)
{
     
	string path = HttpContext.Current.Server.MapPath(null);

	System.IO.StreamReader sr = System.IO.File.OpenText(path + "\\custom\\custom_header.html" );
	Application["custom_header"] = sr.ReadToEnd();
	sr.Close();
	
	sr = System.IO.File.OpenText(path + "\\custom\\custom_footer.html" );
	Application["custom_footer"] = sr.ReadToEnd();
	sr.Close();

	sr = System.IO.File.OpenText(path + "\\custom\\custom_logo.html" );
	Application["custom_logo"] = sr.ReadToEnd();
	sr.Close();
	
}

  
/*
public void Application_BeginRequest(Object sender, EventArgs e)
{

	string day = DateTime.Now.ToString("yyyy-MM-dd");
	
	if (day != prev_day)
	{
		prev_day = day;
		Util.write_to_log("Global.asax detected first page hit of the day");
	}

	
}
*/

</script>