/*
Copyright 2002-2008 Corey Trager
Distributed under the terms of the GNU General Public License
*/

using System;
using System.Data;
using System.Data.SqlClient;

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

            sql = sql.Replace("$username",username.Replace("'","''"));

            DataRow dr = dbutil.get_datarow(sql);

            if (dr == null)
            {
                Util.write_to_log("Unknown user " + username + " attempted to login.");
                return false;
            }

            int us_active = (int) dr["us_active"];

            if (us_active == 0)
            {
                Util.write_to_log("Inactive user " + username + " attempted to login.");
                return false;
            }

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
