package com.github.joostvdg.demo.signal;

public class HelloWorld {

    private volatile boolean stop;

    public HelloWorld() {
        stop=false;
    }

    public void printHelloWorld()  {
        for (int i = 0; i < 100; i++) {
            try {
                Thread.sleep(500);
            } catch (InterruptedException e) {
                e.printStackTrace();
            }
            if (stop) {
                System.out.println("We're told to stop early...");
                return;
            }
            System.out.println("HelloWorld!");
        }
    }

    public void stop() {
        synchronized (this) {
            stop = true;
        }
    }
}
