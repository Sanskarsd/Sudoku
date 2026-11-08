import java.nio.channels.Selector;
import java.net.*;
import java.nio.file.*;
public class SelectorProbe {
 public static void main(String[] args) throws Exception {
  System.out.println("java.version="+System.getProperty("java.version"));
  System.out.println("java.home="+System.getProperty("java.home"));
  System.out.println("java.io.tmpdir="+System.getProperty("java.io.tmpdir"));
  System.out.println("user.dir="+System.getProperty("user.dir"));
  System.out.println("TEMP="+System.getenv("TEMP")+" TMP="+System.getenv("TMP"));
  try (ServerSocket server=new ServerSocket(0,1,InetAddress.getLoopbackAddress())) { try(Socket socket=new Socket(InetAddress.getLoopbackAddress(),server.getLocalPort())) {System.out.println("TCP loopback=OK");}}
  try(Selector selector=Selector.open()){System.out.println("Selector.open=OK provider="+selector.provider());}
 }
}
