package com.github.joostvdg.demo.signal;

import java.util.concurrent.ExecutorService;
import java.util.concurrent.Executors;

public class SignalApp {
    public static void main(String[] args) {
        HelloWorld helloWorld = new HelloWorld();
        ExecutorService executorService = Executors.newFixedThreadPool(1);
        executorService.submit(helloWorld::printHelloWorld);

        Runtime.getRuntime().addShutdownHook(new Thread(() -> {
            System.out.println("Shutdown hook called!");
            helloWorld.stop();
            executorService.shutdown();
            try {
                Thread.sleep(250);
                executorService.shutdownNow();
            } catch (InterruptedException e) {
                e.printStackTrace();
            }
        }));
    }
}
