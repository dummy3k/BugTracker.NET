/*
Copyright 2002-2008 Corey Trager
Distributed under the terms of the GNU General Public License
*/

using System;
using System.Collections;
using System.IO;
using System.Text;

// disable System.Net.Mail warnings
#pragma warning disable 618
#warning System.Web.Mail is deprecated, but it doesn't work yet with "explicit" SSL, so keeping it for now - corey

namespace btnet
{

	public class Email {
		///////////////////////////////////////////////////////////////////////
		public static string send_email( // 5 args
			string to,
			string from,
			string cc,
			string subject,
			string body)
		{
          
            return send_email(
				to,
				from,
				cc,
				subject,
				body,
                "", // XML
				System.Web.Mail.MailFormat.Text,
				System.Web.Mail.MailPriority.Normal,
				null,
				false);
		}

		///////////////////////////////////////////////////////////////////////
		public static string send_email( // 6 args
			string to,
			string from,
			string cc,
			string subject,
			string body,
            string xml,
			System.Web.Mail.MailFormat body_format)
		{
			return send_email(
				to,
				from,
				cc,
				subject,
				body,
                xml,
				body_format,
				System.Web.Mail.MailPriority.Normal,
				null,
				false);
		}

		///////////////////////////////////////////////////////////////////////
		public static string send_email(
			string to,
			string from,
			string cc,
			string subject,
			string body,
            string xml,
            System.Web.Mail.MailFormat body_format,
			System.Web.Mail.MailPriority priority,
			int[] attachment_bpids,
			bool return_receipt)
		{
			ArrayList files_to_delete = new ArrayList();
			ArrayList directories_to_delete = new ArrayList();
			System.Web.Mail.MailMessage msg = new System.Web.Mail.MailMessage();
			msg.To = to;
			msg.From = from;

            if (!string.IsNullOrEmpty(cc.Trim())) 
            {
                msg.Cc = cc; 
            }
			
            msg.Subject = subject;
			msg.Priority = priority;

			// This fixes a bug for a couple people, but make it configurable, just in case.
			if (Util.get_setting("BodyEncodingUTF8", "1") == "1")
			{
				msg.BodyEncoding = Encoding.UTF8;
			}


			if (return_receipt)
			{
                msg.Headers.Add("Disposition-Notification-To", from);
			}

			// workaround for a bug I don't understand...
			if (Util.get_setting("SmtpForceReplaceOfBareLineFeeds", "0") == "1")
			{
				body = body.Replace("\n", "\r\n");
			}

            msg.Body = body;
			msg.BodyFormat = body_format;


			string smtp_server = Util.get_setting("SmtpServer", "");
			if (smtp_server != "")
			{
				System.Web.Mail.SmtpMail.SmtpServer = smtp_server;
			}

			string smtp_password = Util.get_setting("SmtpServerAuthenticatePassword", "");

			if (smtp_password != "")
			{
				msg.Fields["http://schemas.microsoft.com/cdo/configuration/sendpassword"] = smtp_password;
				msg.Fields["http://schemas.microsoft.com/cdo/configuration/smtpauthenticate"] = 1;
				msg.Fields["http://schemas.microsoft.com/cdo/configuration/sendusername"] =
					Util.get_setting("SmtpServerAuthenticateUser", "");
			}

			string smtp_pickup = Util.get_setting("SmtpServerPickupDirectory", "");
			if (smtp_pickup != "")
			{
				msg.Fields["http://schemas.microsoft.com/cdo/configuration/smtpserverpickupdirectory"] = smtp_pickup;
			}


			string send_using = Util.get_setting("SmtpSendUsing", "");
			if (send_using != "")
			{
				msg.Fields["http://schemas.microsoft.com/cdo/configuration/sendusing"] = send_using;
			}


			string smtp_use_ssl = Util.get_setting("SmtpUseSSL", "");
			if (smtp_use_ssl == "1")
			{
				msg.Fields["http://schemas.microsoft.com/cdo/configuration/smtpusessl"] = "true";
			}

			string smtp_server_port = Util.get_setting("SmtpServerPort", "");
			if (smtp_server_port != "")
			{
				msg.Fields["http://schemas.microsoft.com/cdo/configuration/smtpserverport"] = smtp_server_port;
			}

			if (attachment_bpids != null && attachment_bpids.Length > 0)
			{

				string upload_folder = btnet.Util.get_upload_folder();

				if (string.IsNullOrEmpty(upload_folder))
				{
					upload_folder = Path.Combine(Path.GetTempPath(), Path.GetRandomFileName());
					Directory.CreateDirectory(upload_folder);
					directories_to_delete.Add(upload_folder);
				}


				foreach (int attachment_bpid in attachment_bpids)
				{
					byte[] buffer = new byte[16 * 1024];
					string dest_path_and_filename;
					Bug.BugPostAttachment bpa = Bug.get_bug_post_attachment(attachment_bpid);
					using (bpa.content)
					{
						dest_path_and_filename = Path.Combine(upload_folder, bpa.file);
						using (FileStream out_stream = new FileStream(
							dest_path_and_filename,
							FileMode.CreateNew,
							FileAccess.Write,
							FileShare.None))
						{
							int bytes_read = bpa.content.Read(buffer, 0, buffer.Length);
							while (bytes_read != 0)
							{
								out_stream.Write(buffer, 0, bytes_read);

								bytes_read = bpa.content.Read(buffer, 0, buffer.Length);
							}
						}

					}

					System.Web.Mail.MailAttachment mail_attachment = new System.Web.Mail.MailAttachment(
						dest_path_and_filename,
						System.Web.Mail.MailEncoding.Base64);
					msg.Attachments.Add(mail_attachment);
					files_to_delete.Add(dest_path_and_filename);
				}
			}


            // Add XML Attachment
            string xml_tmp_filename = Path.Combine(Path.GetTempPath(), "notification.xml");
            ASCIIEncoding encoder = new ASCIIEncoding();
            using (FileStream xml_out_stream = new FileStream(
                xml_tmp_filename,
                FileMode.Create,
                FileAccess.Write,
                FileShare.None))
            {
                xml_out_stream.Write(
                    encoder.GetBytes(xml),
                    0, //Offset
                    encoder.GetByteCount(xml));
            }

            System.Web.Mail.MailAttachment xml_attachment = new System.Web.Mail.MailAttachment(
                xml_tmp_filename, System.Web.Mail.MailEncoding.Base64);
            msg.Attachments.Add(xml_attachment);
            files_to_delete.Add(xml_tmp_filename);


			try
			{
                // This fixes a bug for some people.  Not sure how it happens....
                msg.Body = msg.Body.Replace(Convert.ToChar(0), ' ').Trim();
                System.Web.Mail.SmtpMail.Send(msg);

				// We delete late here because testing showed that SmtpMail class
				// got confused when we deleted too soon.
				if (files_to_delete.Count > 0)
				{
					foreach (string file in files_to_delete)
					{
						File.Delete(file);
					}
				}

				if (directories_to_delete.Count > 0)
				{
					foreach (string directory in directories_to_delete)
					{
						Directory.Delete(directory);
					}
				}

				return "";
			}
			catch (Exception e)
			{
				Util.write_to_log("There was a problem sending email.   Check settings in Web.config.");
				Util.write_to_log("TO:" + to);
				Util.write_to_log("FROM:" + from);
				Util.write_to_log("SUBJECT:" + subject);
				Util.write_to_log(e.GetBaseException().Message.ToString());
				return (e.GetBaseException().Message);
			}

		}

	} // end Email


} // end namespace