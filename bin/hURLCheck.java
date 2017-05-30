import java.net.*;
import java.io.*;

/*
    HTTP 200 is success, 
    everything else is failure

###############################################################
 #	Author: 	Habib Rangoonwala
 #	Created:	12-DEC-2009
 #	Updated:	05-FEB-2010
###############################################################
   
*/

    public class hURLCheck {

      public static void main(String args[]) {
        if (args.length == 0) {
          System.err.println
            ("NO URL Provided!");
        } else {
          String urlString = args[0];
          try {
            URL url = new URL(urlString);
            URLConnection connection = 
            url.openConnection();
            if (connection instanceof HttpURLConnection) {
              HttpURLConnection httpConnection = 
                 (HttpURLConnection)connection;
              httpConnection.connect();
              int response = 
                 httpConnection.getResponseCode();
              System.out.println(
                 "Response: " + response);
            }
          } catch (IOException e) {
            e.printStackTrace();
          }
        }
      }
   }
