/*
Copyright 2002-2008 Corey Trager
Distributed under the terms of the GNU General Public License
*/

using System;
using System.Data;
using System.Data.SqlClient;
using System.DirectoryServices.Protocols;

namespace btnet
{
	public class Authenticate {

        // returns user id
        public static bool check_password(string username, string password)
        {

            DbUtil dbutil = new DbUtil();

            string sql = @"
select us_username, us_id, us_password, isnull(us_salt,0) us_salt, us_active
from users
where us_username = N'$username'";

            sql = sql.Replace("$username", username.Replace("'", "''"));

            DataRow dr = dbutil.get_datarow(sql);

            if (dr == null)
            {
                Util.write_to_log("Unknown user " + username + " attempted to login.");
                return false;
            }

            int us_active = (int)dr["us_active"];

            if (us_active == 0)
            {
                Util.write_to_log("Inactive user " + username + " attempted to login.");
                return false;
            }

            bool authenticated = false;
            if (btnet.Util.get_setting("AuthenticateUsingLdap","0") == "1")
			{
				authenticated = check_password_with_ldap(username, password);
			}
			else
			{
				authenticated = check_password_with_db(username, password, dbutil, dr);
			}

            if (authenticated)
            {
                sql = @"update users set us_most_recent_login_datetime = getdate() where us_id = $us";
                sql = sql.Replace("$us", Convert.ToString((int)dr["us_id"]));
                dbutil.execute_nonquery(sql);
                return true;
            }
            else
            {
                return false;
            }
		}

		public static bool check_password_with_ldap(string username, string password)
		{
			string dn = btnet.Util.get_setting(
				"LdapUserDistinguishedName",
				"");

			string ldap_server = btnet.Util.get_setting(
				"LdapServer",
				"127.0.0.1");

			dn = dn.Replace("$REPLACE_WITH_USERNAME$", username);
			LdapConnection ldap = new LdapConnection(ldap_server);
			System.Net.NetworkCredential cred = new System.Net.NetworkCredential(dn, password);

            string auth_type = btnet.Util.get_setting(
                "LdapAuthType","Basic");

            if (auth_type == "Basic")
                ldap.AuthType = AuthType.Basic;
            else if (auth_type == "Anonymous")
                ldap.AuthType = AuthType.Anonymous;
            else if (auth_type == "Digest")
                ldap.AuthType = AuthType.Digest;
            else if (auth_type == "Dpa")
                ldap.AuthType = AuthType.Dpa;
            else if (auth_type == "External")
                ldap.AuthType = AuthType.External;
            else if (auth_type == "Kerberos")
                ldap.AuthType = AuthType.Kerberos;
            else if (auth_type == "Msn")
                ldap.AuthType = AuthType.Msn;
            else if (auth_type == "Negotiate")
                ldap.AuthType = AuthType.Negotiate;
            else if (auth_type == "Ntlm")
                ldap.AuthType = AuthType.Ntlm;
            else if (auth_type == "Sicily")
                ldap.AuthType = AuthType.Sicily;

			try
			{
				ldap.Bind(cred);
				btnet.Util.write_to_log("LDAP authentication ok: " + username);
				return true;
			}
			catch (LdapException e)
			{
				string s = e.Message;

				if (e.InnerException != null)
				{
					s += "\n";
					s += e.InnerException.Message;
				}

				// write the message to the log
				btnet.Util.write_to_log("LDAP authentication failed: " + s);
				return false;
			}
		}

        public static bool check_password_with_db(string username, string password, DbUtil dbutil, DataRow dr)
        {

            int us_salt = (int) dr["us_salt"];

            string encrypted;

            string us_password = (string) dr["us_password"];

            if (us_password.Length < 32) // if password in db is unencrypted
            {
				encrypted = password; // in other words, unecrypted
			}
            else if (us_salt == 0)
            {
                encrypted = Util.encrypt_string_using_MD5(password);
            }
            else
            {
                encrypted = Util.encrypt_string_using_MD5(password + Convert.ToString(us_salt));
            }


			if (encrypted == us_password)
            {
                // Authenticated, but let's do a better job encrypting the password.
                // If it is not encrypted, or, if it is encrypted without salt, then
                // update it so that it is encrypted WITH salt.
                if (us_salt == 0 || us_password.Length < 32)
                {
                    btnet.Util.update_user_password(dbutil, (int) dr["us_id"], password);
                }
                return true;
            }
            else
            {
                Util.write_to_log("User " + username + " entered an incorrect password.");
                return false;
            }
        }
    }

}
